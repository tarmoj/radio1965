#pragma once

#include <QAudioFormat>
#include <QByteArray>
#include <QElapsedTimer>
#include <QNetworkAccessManager>
#include <QObject>
#include <QStringList>
#include <QTimer>

struct lame_global_struct;
typedef struct lame_global_struct lame_global_flags;

class QAudioSource;
class QIODevice;
class QTcpSocket;

// Captures microphone audio and streams it to an Icecast2 mountpoint
// (project-description.md #8.1/#9): QAudioSource -> libmp3lame -> a
// hand-rolled Icecast HTTP-source client over QTcpSocket. Built on Desktop
// and Android (see app/CMakeLists.txt's RADIO65_ENABLE_BROADCAST gate,
// which cross-compiles libmp3lame via the NDK on Android) - registered as
// QML context property "icecastBroadcaster" only when that macro is
// defined, so BroadcastPage.qml checks `typeof icecastBroadcaster !==
// "undefined"` rather than relying on a separate platform flag.
class IcecastBroadcaster : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool broadcasting READ isBroadcasting NOTIFY broadcastStateChanged)
    Q_PROPERTY(bool onAir READ isOnAir NOTIFY onAirChanged)
    Q_PROPERTY(int elapsedSeconds READ elapsedSeconds NOTIFY elapsedSecondsChanged)
    // Peak of the most recently captured PCM buffer, post-gain, normalized
    // to [0, 1] - drives BroadcastPage.qml's input level meter. Only ever
    // updates while m_audioSource is actually running (i.e. while
    // broadcasting), since mic capture is tied to startBroadcast().
    Q_PROPERTY(qreal inputLevel READ inputLevel NOTIFY inputLevelChanged)
    // Linear multiplier applied to captured samples before MP3 encoding, so
    // BroadcastPage.qml's gain slider affects the actual streamed signal
    // (and the meter above, which reads post-gain samples) rather than
    // just a UI-only value. 1.0 = unity, clamped to [0, 4] in setGain().
    Q_PROPERTY(qreal gain READ gain WRITE setGain NOTIFY gainChanged)

public:
    explicit IcecastBroadcaster(QObject *parent = nullptr);
    ~IcecastBroadcaster() override;

    bool isBroadcasting() const { return m_broadcasting; }
    bool isOnAir() const { return m_onAir; }
    int elapsedSeconds() const;
    qreal inputLevel() const { return m_inputLevel; }
    qreal gain() const { return m_gain; }
    void setGain(qreal gain);

    // channel: one of "radio1965"/"user1".."user4" (no leading slash).
    // name/description become the ice-name/ice-description headers.
    // sendNotification/saveStream: both forwarded packed into the
    // ice-audio-info header as "send_notification=<0|1>;save_stream=<0|1>"
    // (see server/icecast_on_connect.sh, which reads them back). ice-public
    // was tried first (as a 0/1 "should this publish a notification" flag)
    // but doesn't survive into status-json.xsl at all on this Icecast setup
    // (no <directory> block configured - the "public" field is simply
    // absent from the JSON, confirmed via a live capture). ice-audio-info
    // works instead because Icecast parses its semicolon-separated
    // key=value pairs and hoists *every* key - not just its own recognized
    // ones (bitrate/samplerate/channels) - onto its own top-level field on
    // the source object, e.g. {"audio_info":"save_stream=1;...",
    // "save_stream":1, "send_notification":0, ...}. A brand-new custom
    // ice-* header isn't used here because Icecast only serializes its
    // fixed known header set at all - an invented header name wouldn't be
    // read, let alone reflected into status-json.xsl.
    // TODO(save-stream): server/icecast_on_connect.sh currently only reads
    // and logs this value; there's no recording pipeline behind it yet
    // (see TODOs.md "Save audio stream - if required").
    Q_INVOKABLE void startBroadcast(const QString &channel, const QString &name, const QString &description, bool sendNotification, bool saveStream);
    Q_INVOKABLE void stopBroadcast();

    // Queries http://live.uuu.ee:8001/status-json.xsl and reports which
    // mountpoints are currently occupied via occupiedChannelsChanged().
    // Best-effort: a network failure reports an empty list rather than
    // raising broadcastError, since occupancy is advisory (disables
    // channel choices in the UI), not a hard gate on broadcasting.
    Q_INVOKABLE void refreshOccupiedChannels();

signals:
    void broadcastStateChanged();
    void onAirChanged();
    void elapsedSecondsChanged();
    void broadcastError(const QString &message);
    void occupiedChannelsChanged(const QStringList &occupied);
    void inputLevelChanged();
    void gainChanged();

private slots:
    void onSocketConnected();
    void onSocketReadyRead();
    void onSocketErrorOccurred();
    void onSocketDisconnected();
    void onAudioReadyRead();
    void onElapsedTick();
    void onStatusJsonReply();

private:
    void sendIcecastHandshake(const QString &channel, const QString &name, const QString &description, bool sendNotification, bool saveStream);
    void encodeAndSend(const QByteArray &pcm);
    void teardown();

    QTcpSocket *m_socket = nullptr;
    QAudioSource *m_audioSource = nullptr;
    QIODevice *m_audioDevice = nullptr;
    QNetworkAccessManager m_statusNam;

    lame_global_flags *m_lame = nullptr;

    bool m_broadcasting = false;
    bool m_onAir = false;
    bool m_handshakeAccepted = false;
    qreal m_inputLevel = 0.0;
    qreal m_gain = 1.0;
    QByteArray m_httpResponseBuffer;
    // MP3 bytes encoded before the handshake response arrives - flushed to
    // the socket once accepted, never written mid-handshake.
    QByteArray m_pendingBody;

    QElapsedTimer m_elapsed;
    QTimer m_elapsedTicker;
};
