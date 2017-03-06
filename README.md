# android-generate-vendor

Scripts to extract vendor files from a factory image and generate vendor
makefiles for AOSP.

## Why?

Building custom Android ROMs for a device is harder than it appears. Although Android
is open-source under the Android Open Source Project (AOSP), devices ship dozens of
closed-source binaries ("blobs") that are needed to fully enable all device hardware.
Obtaining these blobs can be...painful.

Even with friendly devices like the Nexus line that distribute these binaries, there
are cases of missing blobs, requiring ROM builders to manually extract these from factory
images. The Nexus 5 (hammerhead), for example, is missing at least two APKs and three shared
libraries in the distributed vendor binaries.

These scripts aim to make the process of extracting vendor files and including them in AOSP
builds simple and scalable.

## Caveats

Right now, we only handle devices that ship all blobs in `/system`. Devices that
use a separate vendor partition are unsupported right now; please see the excellent
[android-prepare-vendor](https://github.com/anestisb/android-prepare-vendor) to deal
with vendor partitions for the latest Nexus devices.

## Supported Devices

* [Nexus 5 (hammerhead)](lge/hammerhead/proprietary-blobs.txt)
* [Nexus 7 2013 Wi-Fi (flo)](asus/flo/proprietary-blobs.txt)

## Dependencies

* [android-simg2img](https://github.com/anestisb/android-simg2img)
* [smali](https://github.com/JesusFreke/smali)

These are included under [deps](deps) for your convenience.

## Examples

Generating a vendor tree for hammerhead build M4B30Z:

```
$ ./generate-vendor.sh -d hammerhead -i hammerhead-m4b30z-factory-625c027b.zip
I: setting up output dir './vendor/lge/hammerhead'...
I: preparing factory image...
W:   requesting sudo for loop mount...
I: generating vendor makefiles...
I: extracting vendor files from image...
I:   de-optimizing system/app/qcrilmsgtunnel/qcrilmsgtunnel.apk...
I:   de-optimizing system/app/shutdownlistener/shutdownlistener.apk...
I:   de-optimizing system/app/TimeService/TimeService.apk...
I:   de-optimizing system/framework/qcrilhook.jar...
I: calculating checksums...
I: all tasks completed successfully
I: cleaning up...
```

...you will end up with a clean vendor tree for your device:

```
$ tree -L 2 vendor/lge/hammerhead
vendor/lge/hammerhead
|-- Android.mk
|-- device-partial.mk
|-- device-vendor.mk
|-- sha1sums.txt
`-- system
    |-- app
    |-- bin
    |-- etc
    |-- framework
    |-- lib
    `-- vendor

7 directories, 4 files
```

Just copy the vendor directory to your AOSP workspace and you're good to go!

## License

[Apache 2.0](LICENSE)
