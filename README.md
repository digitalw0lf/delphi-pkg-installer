# delphi-pkg-installer

Automates installation of packages into Delphi:
1. Compile DCU's for all platform+config combinations
2. Add Search paths and Browsing paths for all selected platforms

Using pre-compiled DCU's for 3rd party libs instead of original sources reduces build times on "Full rebuild".

### Current limitations

* Delphi 10.4 registry paths are hard-coded right now (TODO).
* DelphiPkgInstaller does not supports installing design-time packages into IDE (TODO).
* When appending Search and Browsing paths, it only checks for exact match in existing paths. If directory structure changed in new version of package, old paths may be left in IDE.

### Usage

#### 1. Create Packagename.dpinst config for a package

Copy Template.dpinst to a package root directory and customize it.

#### 2. Install package into Delphi

Run `DelphiPkgInstaller.exe path\to\MyPackage.dpinst`
