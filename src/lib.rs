#[cfg(target_os = "android")]
#[no_mangle]
fn android_main(app: slint::android::AndroidApp) {
    slint::android::init(app).unwrap();

    slint::slint! {
        export component MainWindow inherits Window {
            Text {
                text: "Hello from Slint on Android!";
                font-size: 24px;
            }
        }
    }

    MainWindow::new().unwrap().run().unwrap();
}
