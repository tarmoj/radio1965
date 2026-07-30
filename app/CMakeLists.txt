cmake_minimum_required(VERSION 3.16)

project(radio65 VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTORCC ON) #NB! without this resources are not included

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.5)

if(ANDROID)
    set(QT_ANDROID_MIN_SDK_VERSION 28)
endif()

# Bring the iOS build up incrementally: start with the QML UI only, add the
# notification manager back once APNs integration is ready.
option(RADIO65_ENABLE_NOTIFICATIONS "Build the in-app notification manager" ON)
if(IOS)
    set(RADIO65_ENABLE_NOTIFICATIONS OFF CACHE BOOL "" FORCE)
endif()

qt_add_executable(appradio65
    main.cpp
)

if(RADIO65_ENABLE_NOTIFICATIONS)
    target_sources(appradio65 PRIVATE notificationmanager.h notificationmanager.cpp)
    target_compile_definitions(appradio65 PRIVATE RADIO65_ENABLE_NOTIFICATIONS)
endif()

if(ANDROID)
    target_sources(appradio65 PRIVATE androidpush.cpp)
endif()


qt_add_qml_module(appradio65
    URI radio65
    VERSION 1.0
    QML_FILES
        Main.qml
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
    PRIVATE Qt6::Quick
)

if(ANDROID)
    set_property(TARGET appradio65 PROPERTY QT_ANDROID_PACKAGE_NAME org.eccm.radio65)
    set_property(TARGET appradio65 PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/android)
endif()

if(IOS)
    target_sources(appradio65 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets")
    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets" PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )

    set_target_properties(appradio65 PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER org.eccm.radio65
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME AppIcon
        XCODE_ATTRIBUTE_MARKETING_VERSION ${PROJECT_VERSION}
        XCODE_ATTRIBUTE_CURRENT_PROJECT_VERSION ${PROJECT_VERSION}
        QT_IOS_LAUNCH_SCREEN ${CMAKE_CURRENT_SOURCE_DIR}/ios/LaunchScreen.storyboard
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
