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

public:
    explicit IcecastBroadcaster(QObject *parent = nullptr);
    ~IcecastBroadcaster() override;

    bool isBroadcasting() const { return m_broadcasting; }
    bool isOnAir() const { return m_onAir; }
    int elapsedSeconds() const;

    // channel: one of "radio1965"/"user1".."user4" (no leading slash).
    // name/description become the ice-name/ice-description headers.
    // sendNotification: forwarded as the ice-public header (1/0) - this app
    // never uses Icecast's real public-directory/YP listing feature (no
    // <directory> block is configured), so that header is repurposed as a
    // cheap, guaranteed-to-round-trip-through-status-json.xsl carrier for
    // "should icecast_on_connect.sh publish a notification for this
    // broadcast" (see server/icecast_on_connect.sh, which reads it back via
    // the source's "public" field). A brand-new custom ice-* header isn't
    // used here because Icecast only serializes its fixed known field set
    // into status-json.xsl - an invented header name wouldn't show up there
    // at all.
    Q_INVOKABLE void startBroadcast(const QString &channel, const QString &name, const QString &description, bool sendNotification);
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

private slots:
    void onSocketConnected();
    void onSocketReadyRead();
    void onSocketErrorOccurred();
    void onSocketDisconnected();
    void onAudioReadyRead();
    void onElapsedTick();
    void onStatusJsonReply();

private:
    void sendIcecastHandshake(const QString &channel, const QString &name, const QString &description, bool sendNotification);
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
    QByteArray m_httpResponseBuffer;
    // MP3 bytes encoded before the handshake response arrives - flushed to
    // the socket once accepted, never written mid-handshake.
    QByteArray m_pendingBody;

    QElapsedTimer m_elapsed;
    QTimer m_elapsedTicker;
};
