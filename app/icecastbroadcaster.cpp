#include "icecastbroadcaster.h"

#include <QAudioSource>
#include <QIODevice>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QMediaDevices>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTcpSocket>
#include <QUrl>

#include <lame/lame.h>

namespace {

const char *const ICECAST_HOST = "live.uuu.ee";
const quint16 ICECAST_PORT = 8001;
// TODO: confirm against the live Icecast config - project-description.md
// #8.1's test commands show this value in one example and a <Password>
// placeholder in another, so it isn't certain to still be current.
const char *const ICECAST_PASSWORD = "Tesla100";
const char *const ICE_URL = "eccm.ee";
const char *const ICE_GENRE = "avant-garde";

constexpr int SAMPLE_RATE = 44100;
constexpr int MP3_BITRATE_KBPS = 128;
// Worst-case buffer size per lame.h: 1.25*num_samples + 7200.
constexpr int MP3_BUF_SIZE = static_cast<int>(1.25 * 8192) + 7200;

} // namespace

IcecastBroadcaster::IcecastBroadcaster(QObject *parent)
    : QObject(parent)
{
    m_elapsedTicker.setInterval(1000);
    connect(&m_elapsedTicker, &QTimer::timeout, this, &IcecastBroadcaster::onElapsedTick);
}

IcecastBroadcaster::~IcecastBroadcaster()
{
    teardown();
}

int IcecastBroadcaster::elapsedSeconds() const
{
    return m_broadcasting ? static_cast<int>(m_elapsed.elapsed() / 1000) : 0;
}

void IcecastBroadcaster::startBroadcast(const QString &channel, const QString &name, const QString &description)
{
    if (m_broadcasting)
        return;

    QAudioFormat format;
    format.setSampleRate(SAMPLE_RATE);
    format.setChannelCount(1);
    format.setSampleFormat(QAudioFormat::Int16);

    m_audioSource = new QAudioSource(QMediaDevices::defaultAudioInput(), format, this);
    m_audioDevice = m_audioSource->start();
    if (m_audioDevice)
        connect(m_audioDevice, &QIODevice::readyRead, this, &IcecastBroadcaster::onAudioReadyRead);

    m_lame = lame_init();
    lame_set_in_samplerate(m_lame, SAMPLE_RATE);
    lame_set_num_channels(m_lame, 1);
    lame_set_brate(m_lame, MP3_BITRATE_KBPS);
    lame_init_params(m_lame);

    m_httpResponseBuffer.clear();
    m_pendingBody.clear();
    m_handshakeAccepted = false;

    m_socket = new QTcpSocket(this);
    connect(m_socket, &QTcpSocket::connected, this, &IcecastBroadcaster::onSocketConnected);
    connect(m_socket, &QTcpSocket::readyRead, this, &IcecastBroadcaster::onSocketReadyRead);
    connect(m_socket, &QTcpSocket::errorOccurred, this, &IcecastBroadcaster::onSocketErrorOccurred);
    connect(m_socket, &QTcpSocket::disconnected, this, &IcecastBroadcaster::onSocketDisconnected);

    // Captured for sendIcecastHandshake(), called once connected().
    m_socket->setProperty("channel", channel);
    m_socket->setProperty("name", name);
    m_socket->setProperty("description", description);

    m_socket->connectToHost(QString::fromLatin1(ICECAST_HOST), ICECAST_PORT);

    m_broadcasting = true;
    emit broadcastStateChanged();
    m_elapsed.start();
    m_elapsedTicker.start();
}

void IcecastBroadcaster::sendIcecastHandshake(const QString &channel, const QString &name, const QString &description)
{
    // HTTP/1.0, no Content-Length/Transfer-Encoding: Icecast's source-over-
    // PUT protocol treats the connection as a continuous stream once
    // headers end, matching ffmpeg's icecast:// muxer / libshout, and
    // matching Icecast's own "HTTP/1.0 200 OK"-style reply.
    const QByteArray auth = QByteArray("source:") + ICECAST_PASSWORD;
    QByteArray request;
    request += "PUT /" + channel.toUtf8() + " HTTP/1.0\r\n";
    request += "Authorization: Basic " + auth.toBase64() + "\r\n";
    request += "Content-Type: audio/mpeg\r\n";
    request += "ice-name: " + name.toUtf8() + "\r\n";
    request += "ice-description: " + description.toUtf8() + "\r\n";
    request += QByteArray("ice-genre: ") + ICE_GENRE + "\r\n";
    request += QByteArray("ice-url: ") + ICE_URL + "\r\n";
    request += "ice-public: 0\r\n";
    request += "\r\n";
    m_socket->write(request);
}

void IcecastBroadcaster::onSocketConnected()
{
    sendIcecastHandshake(m_socket->property("channel").toString(),
                          m_socket->property("name").toString(),
                          m_socket->property("description").toString());
}

void IcecastBroadcaster::onSocketReadyRead()
{
    if (m_handshakeAccepted) {
        // Icecast source connections don't send anything further after the
        // initial response - just drain to avoid unbounded buffering.
        m_socket->readAll();
        return;
    }

    m_httpResponseBuffer += m_socket->readAll();
    const int lineEnd = m_httpResponseBuffer.indexOf("\r\n");
    if (lineEnd < 0)
        return;

    const QByteArray statusLine = m_httpResponseBuffer.left(lineEnd);
    if (statusLine.contains(" 200")) {
        m_handshakeAccepted = true;
        m_onAir = true;
        emit onAirChanged();
        if (!m_pendingBody.isEmpty()) {
            m_socket->write(m_pendingBody);
            m_pendingBody.clear();
        }
    } else {
        emit broadcastError(QString::fromUtf8("Icecast rejected the connection: " + statusLine));
        teardown();
    }
}

void IcecastBroadcaster::onSocketErrorOccurred()
{
    if (!m_broadcasting)
        return;
    emit broadcastError(m_socket->errorString());
    teardown();
}

void IcecastBroadcaster::onSocketDisconnected()
{
    if (m_broadcasting)
        teardown();
}

void IcecastBroadcaster::onAudioReadyRead()
{
    if (!m_audioDevice)
        return;
    const QByteArray pcm = m_audioDevice->readAll();
    if (!pcm.isEmpty())
        encodeAndSend(pcm);
}

void IcecastBroadcaster::encodeAndSend(const QByteArray &pcm)
{
    if (!m_lame)
        return;

    const auto *samples = reinterpret_cast<const short int *>(pcm.constData());
    const int numSamples = static_cast<int>(pcm.size() / sizeof(short int));

    QByteArray mp3Buf(MP3_BUF_SIZE, Qt::Uninitialized);
    // Mono input: LAME's own convention is to pass the same buffer as both
    // the left and right channel argument (see lame.h's lame_encode_buffer
    // docs) rather than a null right-channel pointer.
    const int written = lame_encode_buffer(m_lame, samples, samples, numSamples,
                                            reinterpret_cast<unsigned char *>(mp3Buf.data()), mp3Buf.size());
    if (written <= 0)
        return;

    if (m_handshakeAccepted && m_socket && m_socket->state() == QAbstractSocket::ConnectedState)
        m_socket->write(mp3Buf.constData(), written);
    else
        m_pendingBody += QByteArray(mp3Buf.constData(), written);
}

void IcecastBroadcaster::stopBroadcast()
{
    if (!m_broadcasting)
        return;

    if (m_lame && m_socket && m_handshakeAccepted) {
        QByteArray mp3Buf(MP3_BUF_SIZE, Qt::Uninitialized);
        const int written = lame_encode_flush(m_lame, reinterpret_cast<unsigned char *>(mp3Buf.data()), mp3Buf.size());
        if (written > 0)
            m_socket->write(mp3Buf.constData(), written);
    }

    teardown();
}

void IcecastBroadcaster::teardown()
{
    m_elapsedTicker.stop();

    if (m_audioSource) {
        m_audioSource->stop();
        m_audioSource->deleteLater();
        m_audioSource = nullptr;
    }
    m_audioDevice = nullptr;

    if (m_lame) {
        lame_close(m_lame);
        m_lame = nullptr;
    }

    if (m_socket) {
        m_socket->disconnectFromHost();
        m_socket->deleteLater();
        m_socket = nullptr;
    }

    m_httpResponseBuffer.clear();
    m_pendingBody.clear();

    const bool wasBroadcasting = m_broadcasting;
    const bool wasOnAir = m_onAir;
    m_broadcasting = false;
    m_onAir = false;
    m_handshakeAccepted = false;

    if (wasBroadcasting)
        emit broadcastStateChanged();
    if (wasOnAir)
        emit onAirChanged();
}

void IcecastBroadcaster::onElapsedTick()
{
    emit elapsedSecondsChanged();
}

void IcecastBroadcaster::refreshOccupiedChannels()
{
    const QUrl url(QString("http://%1:%2/status-json.xsl").arg(QString::fromLatin1(ICECAST_HOST)).arg(ICECAST_PORT));
    QNetworkReply *reply = m_statusNam.get(QNetworkRequest(url));
    connect(reply, &QNetworkReply::finished, this, &IcecastBroadcaster::onStatusJsonReply);
}

void IcecastBroadcaster::onStatusJsonReply()
{
    auto *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply)
        return;
    reply->deleteLater();

    QStringList occupied;
    if (reply->error() == QNetworkReply::NoError) {
        const QJsonObject root = QJsonDocument::fromJson(reply->readAll()).object();
        const QJsonValue sourceVal = root.value("icestats").toObject().value("source");
        // icestats.source is a single object with exactly one active
        // source, or an array with several - same defensive single-vs-list
        // normalization already used for Joomla's JSON:API "data" field in
        // server/main.py's GET /articles/{id}.
        const QJsonArray sources = sourceVal.isArray() ? sourceVal.toArray() : QJsonArray{sourceVal};
        for (const QJsonValue &sourceValue : sources) {
            const QString listenUrl = sourceValue.toObject().value("listenurl").toString();
            const int lastSlash = listenUrl.lastIndexOf('/');
            if (lastSlash >= 0)
                occupied << listenUrl.mid(lastSlash + 1);
        }
    }
    emit occupiedChannelsChanged(occupied);
}
