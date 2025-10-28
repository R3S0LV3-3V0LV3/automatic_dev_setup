### Final Technical Requirements Specification (v2.3): macOS Environment Purge and Preservation Utility

#### 1.0 System Objective & Configuration

* **1.1 Objective:** To develop a reusable, automated utility that performs a targeted purge of a macOS environment (applications, development tools, and configurations) while explicitly preserving the functionality and configuration of the RealVNC remote access suite.
* **1.2 Runtime Configuration:**
    * **1.2.1:** The utility *must* support an optional command-line argument (`--output-dir <path>`) specifying a persistent, safe location for all exported manifests and logs.
    * **1.2.2:** If the `--output-dir` argument is *not* provided, the utility *must* interactively prompt the user to provide a path.
    * **1.2.3:** The utility *must* validate the provided path. If it does not exist, it must ask the user for permission to create it (e.g., `mkdir -p "$PATH"`).
    * **1.2.4:** The utility *must* halt if the path is an existing file, if the directory (after a creation attempt) is not writable, or if the target volume has less than 1 GB of free disk space.
    * **1.2.5:** The utility *must* detect if the path is within the target user's Home directory (e.g., `/Users/$TARGET_USER/Desktop`). If so, it *must* display a warning that this location will be purged and recommend a safer path (e.g., `/Users/Shared/SystemBackup`).
    * **1.2.6:** The utility *must* default to an interactive mode, requiring user confirmation at each critical stage.
    * **1.2.7:** An optional non-interactive flag (e.g., `--yes`) shall be supported for automation, but it *must not* bypass "Priority 0" safety checks (2.2.3).
* **1.3 Target User Configuration:**
    * **1.3.1:** The utility *must* support an optional command-line argument (`--target-user <username>`) to specify the user account to be purged.

---

#### 2.0 Pre-Execution Safeguards & Analysis

* **2.1 Privilege & Target User Acquisition:**
    * **2.1.1:** The utility's first action *must* be to check if it is running with superuser privileges (e.g., `[ "$EUID" -eq 0 ]`).
    * **2.1.2:** If the `EUID` is **0** (i.e., the user ran `sudo ./script.sh`), proceed.
    * **2.1.3:** If the `EUID` is **not 0** (i.e., the user ran `./script.sh`), the utility *must* inform the user that admin privileges are required and immediately re-execute itself using `sudo`, passing all original arguments (e.g., `exec sudo "$0" "$@"`).
    * **2.1.4:** This re-execution will trigger the standard system `[sudo] password for [current_user]:` prompt. If this authentication fails, the utility will halt.
    * **2.1.5:** (Now running as root) The utility *must* determine the `TARGET_USER`.
    * **2.1.6:** If the `--target-user` argument (1.3.1) was provided, that value *must* be used.
    * **2.1.7:** If no argument was provided, the utility *must* interactively prompt: `Enter the username of the account to purge:`
    * **2.1.8:** The utility *must* store this value as a `TARGET_USER` variable.
    * **2.1.9:** The utility *must* validate the `TARGET_USER` exists (e.g., via `id -u "$TARGET_USER"`). If the user does not exist, the utility *must* halt with a "Target User Not Found" error.
* **2.2 Remote Access Redundancy (Priority 0):**
    * **2.2.1:** The utility *must* programmatically check the status of the system's SSH server via `systemsetup -getremotelogin`.
    * **2.2.2:** If "Remote Login" is "Off," the utility *must* first ask the user if it should attempt to enable it programmatically (via `systemsetup -setremotelogin on`). If the user declines or the command fails, the utility *must* halt.
    * **2.2.3:** If "Remote Login" is "On" (or was successfully enabled), the utility *must* display a "Priority 0" confirmation prompt, instructing the user to *now* test their SSH connection (as `$TARGET_USER`) from another device before proceeding. This confirmation *cannot* be bypassed by the `--yes` flag.
    * **2.2.4:** The utility *must* add the following paths (if they exist) to the Preservation Allow List:
        * `/etc/ssh/sshd_config`
        * `/Users/$TARGET_USER/.ssh/authorized_keys`
        * `/Users/$TARGET_USER/.ssh/config`
* **2.3 RealVNC Preservation Analysis (Priority 1):**
    * **2.3.1:** The utility *must* discover all RealVNC components using the following mechanisms:
        * **A) Package Receipts:** Query the `pkgutil` database for all files associated with package identifiers matching `com.realvnc.*` (e.g., `pkgutil --files com.realvnc.vncserver`).
        * **B) Bundle Identifiers:** Use Spotlight metadata search (`mdfind`) to locate all files/bundles where `kMDItemCFBundleIdentifier` matches `com.realvnc.*`. (The utility *must* first verify Spotlight is enabled via `mdutil -s /` and warn the user if it is not).
        * **C) Running Services:** Query `launchctl` for all loaded services (daemons and agents) with labels matching `com.realvnc.*` and store their on-disk `.plist` paths (e.g., `launchctl list | grep com.realvnc`).
    * **2.3.2:** The utility *must* perform a redundant scan of all system-level paths (`/Library/`) and `$TARGET_USER`'s user-level paths (`/Users/$TARGET_USER/Library/`) for `LaunchAgents`, `LaunchDaemons`, `Preferences`, and `Application Support` files/folders containing "RealVNC" or "vncserver".
    * **2.3.3:** This scan must explicitly identify and catalog the path to the primary RealVNC `LaunchDaemon` (e.g., `/Library/LaunchDaemons/com.realvnc.vncserver.plist`).
    * **2.3.4:** All unique, absolute file and directory paths identified in 2.3.1-2.3.3 shall be compiled into the definitive "Preservation Allow List."
    * **2.3.5:** After compiling the Preservation Allow List, the utility *must* present a summary to the user (e.g., "Found X files and Y directories to preserve").
    * **2.3.6:** The utility *must* offer the user the choice to 1) View the full list, 2) Approve the list and continue, or 3) Abort. The utility *must not* proceed without user approval.

---

#### 3.0 Data Export & Backup Phase

* **3.1 Dependency Check (Executed as `$TARGET_USER`):**
    * **3.1.1:** The utility *must* verify the existence of `brew` and `mas` *within the context of the target user* via `sudo -u $TARGET_USER which brew` and `sudo -u $TARGET_USER which mas`.
    * **3.1.2:** If `brew` is missing, the utility *must* halt and provide the official command to install it.
    * **3.1.3:** If `brew` is present but `mas` is missing, the utility *must* ask the user for permission to install it via `sudo -u $TARGET_USER brew install mas`.
* **3.2 Manifest Export (Executed as `$TARGET_USER`):**
    * **3.2.1:** Execute as `$TARGET_USER`: `sudo -u $TARGET_USER brew bundle dump --force --file="<output-dir>/Brewfile"`
    * **3.2.2:** Execute as `$TARGET_USER`: `sudo -u $TARGET_USER mas list > "<output-dir>/MAS_App_List.txt"`
* **3.3 Cache Preservation (Executed as `$TARGET_USER`):**
    * **3.3.1:** The utility *must* programmatically determine the Homebrew cache path via `sudo -u $TARGET_USER brew --cache`.
    * **3.3.2:** This cache directory path *must* be added to the Preservation Allow List (2.3.4).

---

#### 4.0 System Purge & Reset Phase

* **4.1 Exclusion Mandate:**
    * **4.1.1:** All operations within this phase *must* programmatically check against the Preservation Allow List. Any file, directory, or process matching an entry on the list *must* be skipped.
    * **4.1.2:** The purge logic *must not* use recursive force deletion (e.g., `rm -rf`) on any directory that is a *parent* of a path on the Preservation Allow List (e.g., `/Library/Application Support`). Instead, it *must* iterate the contents of that directory and evaluate each item individually.
* **4.2 Running Process Check:**
    * **4.2.1:** Before uninstalling any application, the utility *must* check for running processes associated with it.
    * **4.2.2:** If running processes are found, the utility *must* list them and interactively ask the user for permission to terminate them (e.g., `pkill`) before proceeding with the uninstallation.
* **4.3 Application Removal (Executed as `$TARGET_USER`):**
    * **4.3.1 (Homebrew):** Get a list of all installed formulae/casks (via `sudo -u $TARGET_USER brew list ...`). For each item *not* on the Preservation Allow List, execute `sudo -u $TARGET_USER brew uninstall --zap <item>`.
    * **4.3.2 (MAS):** Parse the `MAS_App_List.txt`. For each application ID *not* on the Preservation Allow List, execute `sudo -u $TARGET_USER mas uninstall <id>`.
    * **4.3.3 (Manual .app):** Scan `/Applications` and `/Users/$TARGET_USER/Applications`. For any `.app` bundle *not* on the Preservation Allow List:
        * **A)** Do *not* delete if the bundle identifier matches `com.apple.*`.
        * **B)** Otherwise, delete the `.app` bundle (e.g., `rm -rf "/Applications/SomeApp.app"`).
* **4.4 Configuration & Data Purge:**
    * **4.4.1:** For *every* application uninstalled in 4.3, the utility *must* attempt to find and delete corresponding configuration files and directories from the following locations (checking against the Allow List at each step):
        * `/Users/$TARGET_USER/Library/Application Support/`
        * `/Users/$TARGET_USER/Library/Preferences/`
        * `/Users/$TARGET_USER/Library/Caches/`
        * `/Users/$TARGET_USER/Library/LaunchAgents/`
        * `/Library/Application Support/`
        * `/Library/Preferences/`
        * `/Library/Caches/`
        * `/Library/LaunchAgents/`
        * `/Library/LaunchDaemons/`
* **4.5 Environment Reset (Targeting `$TARGET_USER`):**
    * **4.5.1:** The utility *must* rename (e.g., `mv "$FILE" "$FILE.bak"`) the following files *only* if they exist at `/Users/$TARGET_USER/` and are *not* on the Preservation Allow List:
        * `.zshrc`
        * `.zshenv`
        * `.zprofile`
        * `.bashrc`
        * `.bash_profile`
        * `.profile`
        * `.bash_login`
        * `.gitconfig`
        * `.npmrc`
* **4.6 Purge Limitations:**
    * **4.6.1:** The utility *shall not* attempt to uninstall applications installed via unknown `.pkg` installers (those not identified in 2.3.1).
    * **4.6.2:** A list of all remaining non-Apple package receipts (from `pkgutil --pkgs`) shall be saved to `<output-dir>/manual_review.txt` for user review.

---

#### 5.0 Post-Execution Verification

* **5.1 RealVNC Service Verification:**
    * **5.1.1:** The utility *must* verify that the RealVNC `LaunchDaemon` path (cataloged in 2.3.3) still exists.
    * **5.1.2:** It *must* query `launchctl list` to confirm the service is still loaded and running (e.g., `launchctl list | grep com.realvnc.vncserver`).
    * **5.1.3:** If the service is not running, it shall attempt *only* to reload the existing, preserved `.plist` file (e.g., `launchctl load /Library/LaunchDaemons/com.realvnc.vncserver.plist`).
    * **5.1.4:** If the file is missing or the load fails, the utility must report a "Critical Preservation Failure" message to `stderr` and *must* exit with a non-zero status code (e.g., `exit 2`).

---

#### 6.0 Operational & Safety Requirements

* **6.1 Idempotency:** The utility must be idempotent, meaning it can be run multiple times without causing unintended side effects or errors on a system that has already been purged.
* **6.2 Non-Destructive to OS:** The utility *must not* alter, delete, or corrupt any core macOS system files, specifically any path protected by System Integrity Protection (SIP) or any file/bundle matching `com.apple.*`.
* **6.3 Encapsulation:** All logic (Phases 2.0-5.0) shall be encapsulated into a single, executable script.
* **6.4 Fail-Safe:** The utility must include robust error handling and halt execution immediately if pre-execution safeguards (e.g., Privilege Check, SSH Test) are not met.
* **6.5 Logging:**
    * **6.5.1:** The utility *must* create a verbose, timestamped log file in the specified output directory (1.2.1).
    * **6.5.2:** The log file *must* begin with a header containing the utility version, the `macOS` version (from `sw_vers`), and the timestamp.
    * **6.5.3:** This log must document *every* decision and action, including:
        * All files/paths added to the Preservation Allow List.
        * Every file/directory/app successfully deleted.
        * Every file/directory/app explicitly skipped due to the Allow List.
        * All errors encountered.
    * **6.5.4:** The log file *must* end with a summary, including: "Total Items Purged," "Total Items Preserved," and a final "Status: SUCCESS / FAILURE."