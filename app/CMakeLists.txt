cmake_minimum_required(VERSION 3.16)

project(radio65 VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTORCC ON) #NB! without this resources are not included

find_package(Qt6 REQUIRED COMPONENTS Quick Network Multimedia WebView)

qt_standard_project_setup(REQUIRES 6.5)

if(ANDROID)
    set(QT_ANDROID_MIN_SDK_VERSION 28)

    # Android blocks apps from loading the *system* libcrypto.so/libssl.so
    # (linker namespace isolation, see the "not accessible for the
    # namespace" dlopen error) - Qt::Network's TLS backend (needed for every
    # HTTPS call EventsApiClient makes) needs its own bundled copies, or it
    # fails at runtime with "No functional TLS backend was found". Point
    # this at a checkout of https://github.com/KDAB/android_openssl;
    # defaults to this machine's existing copy under the Android SDK.
    set(RADIO65_ANDROID_OPENSSL_DIR "/home/tarmo/Android/Sdk/android_openssl" CACHE PATH
        "Path to a github.com/KDAB/android_openssl checkout (provides libcrypto/libssl for Android)")
endif()

if(IOS)
    enable_language(OBJCXX)
    enable_language(Swift)
endif()

if(NOT ANDROID AND NOT IOS)
    # Icecast broadcasting (project-description.md #8.1/#9) is desktop-only
    # for now - mobile mic capture/encoding is a separate future effort.
    # libmp3lame is used instead of linking Qt's bundled FFmpeg directly:
    # that FFmpeg build ships no public C headers and has no Android/Desktop
    # linking helper (qt_add_ios_ffmpeg_libraries below is iOS-only).
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(MP3LAME REQUIRED IMPORTED_TARGET libmp3lame)
    set(RADIO65_ENABLE_BROADCAST TRUE)
endif()

option(RADIO65_ENABLE_NOTIFICATIONS "Build the in-app notification manager" ON)

qt_add_executable(appradio65
    main.cpp
    eventsapiclient.h eventsapiclient.cpp
)

if(RADIO65_ENABLE_NOTIFICATIONS)
    target_sources(appradio65 PRIVATE notificationmanager.h notificationmanager.cpp)
    target_compile_definitions(appradio65 PRIVATE RADIO65_ENABLE_NOTIFICATIONS)
endif()

if(RADIO65_ENABLE_BROADCAST)
    target_sources(appradio65 PRIVATE icecastbroadcaster.h icecastbroadcaster.cpp)
    target_compile_definitions(appradio65 PRIVATE RADIO65_ENABLE_BROADCAST)
endif()

if(ANDROID)
    target_sources(appradio65 PRIVATE androidpush.cpp)
endif()

if(IOS)
    target_sources(appradio65 PRIVATE iospush.mm "${CMAKE_CURRENT_SOURCE_DIR}/ios/Radio65SwiftSupport.swift")
endif()


qt_add_qml_module(appradio65
    URI radio65
    VERSION 1.0
    QML_FILES
        Main.qml
        EventListView.qml
        EventDelegate.qml
        WebViewPage.qml
        PlayerPage.qml
        BroadcastPage.qml
        RESOURCES resources.qrc
)

qt_add_resources(appradio65 "conf"
    PREFIX "/"
    FILES qtquickcontrols2.conf
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appradio65 PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appradio65
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appradio65
    PRIVATE Qt6::Quick Qt6::Network Qt6::Multimedia Qt6::WebView
)

if(RADIO65_ENABLE_BROADCAST)
    target_link_libraries(appradio65 PRIVATE PkgConfig::MP3LAME)
endif()

if(ANDROID)
    set_property(TARGET appradio65 PROPERTY QT_ANDROID_PACKAGE_NAME org.eccm.radio65)
    set_property(TARGET appradio65 PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/android)

    if(EXISTS "${RADIO65_ANDROID_OPENSSL_DIR}/android_openssl.cmake")
        include("${RADIO65_ANDROID_OPENSSL_DIR}/android_openssl.cmake")
        add_android_openssl_libraries(appradio65)
    else()
        message(WARNING "RADIO65_ANDROID_OPENSSL_DIR (${RADIO65_ANDROID_OPENSSL_DIR}) not found - "
            "HTTPS requests will fail at runtime with \"No functional TLS backend was found\". "
            "Set -DRADIO65_ANDROID_OPENSSL_DIR=/path/to/android_openssl (see "
            "https://github.com/KDAB/android_openssl).")
    endif()
endif()

if(IOS)
    target_sources(appradio65 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets")
    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )

    # GoogleService-Info.plist must land at the bundle root (not a subfolder) for
    # [FIRApp configure] to find it via [NSBundle mainBundle]. "Resources" maps to
    # the iOS bundle root (no Contents/Resources nesting like on macOS).
    target_sources(appradio65 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/ios/GoogleService-Info.plist")
    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/ios/GoogleService-Info.plist" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )

    set_target_properties(appradio65 PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER org.eccm.radio65
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME AppIcon
        XCODE_ATTRIBUTE_MARKETING_VERSION ${PROJECT_VERSION}
        XCODE_ATTRIBUTE_CURRENT_PROJECT_VERSION ${PROJECT_VERSION}
        QT_IOS_LAUNCH_SCREEN ${CMAKE_CURRENT_SOURCE_DIR}/ios/LaunchScreen.storyboard
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS ${CMAKE_CURRENT_SOURCE_DIR}/ios/radio65.entitlements
        XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
        XCODE_ATTRIBUTE_ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES "YES"
    )

    # Firebase iOS SDK is vendored manually (no CocoaPods/SPM) - run
    # ios/scripts/fetch_firebase_sdk.sh first to populate ios/Firebase.
    file(GLOB RADIO65_FIREBASE_FRAMEWORKS "${CMAKE_CURRENT_SOURCE_DIR}/ios/Firebase/*.xcframework")
    if(NOT RADIO65_FIREBASE_FRAMEWORKS)
        message(FATAL_ERROR "No Firebase XCFrameworks found in ios/Firebase - run ios/scripts/fetch_firebase_sdk.sh first.")
    endif()
    target_link_libraries(appradio65 PRIVATE
        ${RADIO65_FIREBASE_FRAMEWORKS}
        "-framework SystemConfiguration"
        "-framework Security"
        "-framework CFNetwork"
        "-framework UserNotifications"
    )

    # Not needed yet for the first UI-only build; enable once HLS/RTMP stream
    # playback via QtMultimedia is wired up.
    qt_add_ios_ffmpeg_libraries(appradio65)
endif()

include(GNUInstallDirs)
install(TARGETS appradio65
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
