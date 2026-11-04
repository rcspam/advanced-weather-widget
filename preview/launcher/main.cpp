// The qml tool is not installed here: this opens one QML file in a window
// of its own, with the system Qt, so the same QtWebEngine and Kirigami as
// the widget. WebEngineView only needs shared OpenGL contexts set before the
// application exists.
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QUrl>

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QApplication app(argc, argv);
    if (argc < 2) return 2;
    QQmlApplicationEngine engine;
    engine.load(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    if (engine.rootObjects().isEmpty()) return 1;
    return app.exec();
}
