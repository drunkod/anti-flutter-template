# .idx/overlays/android.nix
final: prev: {
  androidPlatformVersion = "35";

  androidEnv = prev.androidenv.override { licenseAccepted = true; };

  androidComposition = final.androidEnv.composeAndroidPackages {
    cmdLineToolsVersion = "8.0";
    includeNDK = true;
    ndkVersion = "25.2.9519653";

    platformVersions = [
      "30"
      "34"
      final.androidPlatformVersion
    ];

    includeEmulator = false;
    includeSystemImages = false;

    abiVersions = [
      "armeabi-v7a"
      "arm64-v8a"
    ];

    cmakeVersions = [ "3.10.2" ];
  };

  androidSdk = final.androidComposition.androidsdk;
}
