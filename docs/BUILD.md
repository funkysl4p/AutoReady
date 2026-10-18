# AutoReady – build

## CI (GitHub Actions)

`.github/workflows/build.yml` runs on pushes to `main` and on pull requests that change the sources (`AutoReady/Classes/`), the build scripts (`scripts/`, `tools/`), `ut-patch.conf` or the workflow itself; documentation-only changes do not trigger it. It always runs for `vX.Y` tags and can be started by hand (Actions → Build → Run workflow). It:

- installs UT99 GOTY + the OldUnreal patch selected in `ut-patch.conf` with the official OldUnreal installer (`scripts/setup-ut.sh`, accepting the Epic Games Terms of Service);
- caches that installation per patch tag, so the game is downloaded again only when the patch changes (`UT_PATCH=newest` also follows release candidates);
- compiles `AutoReady.u` with `scripts/compile.sh` and uploads it with its md5 and the `ucc make` log.

Pushing a tag `vX.Y` also publishes a GitHub Release with `AutoReady.u` and its md5.

## Local

Against any complete UT99 Linux installation:

```bash
scripts/compile.sh <ut99-dir>      # output in build/
```

## Manual procedure

What `scripts/compile.sh` does, step by step.

On Linux, `ucc-bin-amd64` (469e and 469f) needs a small helper library, otherwise `ucc make` hangs on "Analyzing..." and runs out of memory.

**The bug.** When scanning sources in `Classes/`, `ucc make` does not skip the `.` entry (the directory itself) and recurses endlessly into `Classes/./././…`. It happens with any package, even a 3-line mutator. The `nodots.so` library, loaded with `LD_PRELOAD`, hides `.` and `..` from directory listings.

**Requirements:** a complete UT99 Linux installation (`System`, `SystemLocalized`, `Textures`, `Sounds`). Without `Sounds`, Botpack fails to load and `ucc` tries to recompile it.

**Procedure**

1. Build the library (once), from `tools/nodots.c` in this repository:

   ```bash
   gcc -shared -fPIC -o nodots.so tools/nodots.c -ldl
   ```

2. Put the source in `<ut99>/AutoReady/Classes/AutoReady.uc`. The `Classes` folder must contain **only `.uc` files**.
3. Create `System/Build.ini` by copying `Default.ini` and keeping only these `EditPackages`, in this order: `Core`, `Engine`, `Editor`, `UWindow`, `Fire`, `IpDrv`, `UWeb`, `UBrowser`, `UnrealShare`, `UnrealI`, `UMenu`, `Botpack`, `AutoReady`. Later packages (UTMenu etc.) are not needed and, without their sources, break the build.
4. Delete the old `System/AutoReady.u`: if it exists, `ucc` does not recompile.
5. Compile:

   ```bash
   cd <ut99>/System
   LD_PRELOAD=/path/to/nodots.so ./ucc-bin-amd64 make ini=Build.ini -nohomedir
   ```

It must end with `Success - 0 error(s), 0 warnings`. `Failed to load AutoReady` warnings before compilation are normal.
