# comfyui-keepawake

Keeps a Windows PC that runs ComfyUI awake while ComfyUI is in use, and lets it sleep once nobody has used it for 30 minutes.

## Why it's needed

The PC uses a lot of power, so it should sleep when idle. Two things go wrong with Windows' own sleep timer:

- When a Wake-on-LAN packet wakes the PC and nobody touches its keyboard or mouse, Windows treats the wake as unattended and sleeps again after about 2 minutes.
- Windows doesn't count network traffic or GPU work as activity, so someone using ComfyUI from another machine, or a long-running job, gets cut off by the normal sleep timer.

## Why there are two parts

ComfyUI runs in a Linux container, so it can't call Windows power APIs. So the work is split:

- **`custom_node/`**: a ComfyUI custom node. Its browser script watches for keyboard, mouse, wheel and touch input on the ComfyUI page. While the tab is visible and someone has used it in the last 3 minutes, it sends `POST /keepawake/ping` once a minute. The server side records the time of the last ping and serves `GET /keepawake/status`. An open tab that nobody touches sends no pings, which is why this is measured in the browser rather than by watching network traffic.
- **`windows/`**: a PowerShell script that runs in the background on Windows. Every minute it reads `/keepawake/status` and keeps the PC awake while any of these is true:
  1. a job is running or queued;
  2. a ping arrived in the last 30 minutes;
  3. the PC started or resumed less than 30 minutes ago, so a Wake-on-LAN wake doesn't fall back asleep before anyone starts working.

  It keeps the PC awake by calling `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED)`. When none of the three holds, it clears that request and Windows' normal sleep timer takes over. If ComfyUI can't be reached (for example, the container hasn't started yet), the script treats ComfyUI as unused, so only condition 3 can keep the PC awake.

Waking the PC is not part of this repo; anything that sends a Wake-on-LAN packet works.

## The status endpoint

`GET /keepawake/status` (also served at `/api/keepawake/status`) is the contract between the two parts. Change both together.

```json
{
  "last_ping": 1791460800.123,
  "jobs_running": 1,
  "jobs_queued": 2,
  "busy": true,
  "server_time": 1791460860.456
}
```

| Field          | Type           | Meaning                                                                                                                 |
| -------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `last_ping`    | number or null | Server time of the last `POST /keepawake/ping`, in Unix seconds. `null` if there hasn't been one since ComfyUI started. |
| `jobs_running` | integer        | Jobs executing now.                                                                                                     |
| `jobs_queued`  | integer        | Jobs waiting in the queue.                                                                                              |
| `busy`         | boolean        | `true` if any job is running or queued.                                                                                 |
| `server_time`  | number         | The server's current time, in Unix seconds.                                                                             |

The Windows script measures how long ago the last ping was as `server_time - last_ping`, both from ComfyUI's clock, so it doesn't matter if the container's clock disagrees with Windows'.

`POST /keepawake/ping` takes no body and returns `{"last_ping": <server time>}`.

## Install

### 1. The custom node

ComfyUI loads the node from the top of this repo, so a clone of the whole repo in `custom_nodes/` works.

ComfyUI-Manager's **Install via Git URL** works only when ComfyUI listens on a loopback address (`--listen 127.0.0.1`) and `allow_git_url_install = true` is set in Manager's `config.ini`. A Docker container normally listens on `0.0.0.0`, so Manager refuses. Clone the repo into the container's `custom_nodes` folder instead. For the `yanwk/comfyui-boot` image, that's `/root/ComfyUI/custom_nodes`:

```powershell
docker exec <container> git clone https://github.com/lukebarton/comfyui-keepawake /root/ComfyUI/custom_nodes/comfyui-keepawake
docker restart <container>
```

`docker ps` lists container names. If `custom_nodes` is a folder mounted from Windows, you can clone into that folder instead. To update, run `git pull` in the clone and restart ComfyUI.

The node adds nothing to the node list; it only adds the HTTP routes and the browser script.

### 2. The Windows script

Open PowerShell as administrator (right-click > Run as administrator) and run:

```powershell
$ref = "v0.1.0"; & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/lukebarton/comfyui-keepawake/$ref/windows/install.ps1"))) -Ref $ref
```

This downloads `install.ps1` from that release tag. The installer then:

- downloads `keepawake.ps1` from the same tag into `C:\ProgramData\comfyui-keepawake\`;
- registers a scheduled task, **ComfyUI keep awake**, that runs the script as SYSTEM at boot, at logon and on resume from sleep (each trigger restarts the script, so the 30 minutes in condition 3 count from the latest one);
- starts the task.

From a clone, run `.\windows\install.ps1` in an admin PowerShell window instead.

To remove it, run `windows\uninstall.ps1` the same way, or:

```powershell
$ref = "v0.1.0"; & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/lukebarton/comfyui-keepawake/$ref/windows/uninstall.ps1")))
```

### Windows sleep timer

The script only stops Windows sleeping; Windows' own timer still decides when to sleep after the script lets go. Set it in **Settings > System > Power > Screen and sleep > When plugged in, put my device to sleep after**. With a 2-minute timer, the PC sleeps about 2 minutes after the script stops holding it awake.

## Settings

Pass these to the install command (the one-liner or `install.ps1`). To change them, run the install again; it replaces the task.

| Setting                 | Default                 | Meaning                                                                      |
| ----------------------- | ----------------------- | ---------------------------------------------------------------------------- |
| `-ComfyUrl`             | `http://localhost:8188` | Where the script reaches ComfyUI from Windows.                               |
| `-IdleMinutes`          | `30`                    | How long after the last ping, or after boot or resume, to keep the PC awake. |
| `-CheckIntervalSeconds` | `60`                    | How often the script checks.                                                 |

For example:

```powershell
$ref = "v0.1.0"; & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/lukebarton/comfyui-keepawake/$ref/windows/install.ps1"))) -Ref $ref -IdleMinutes 45
```

## Check it's working

- **The status endpoint.** In PowerShell on the PC: `irm http://localhost:8188/keepawake/status`. If this fails, the custom node isn't loaded; check the ComfyUI log for `comfyui-keepawake`.
- **The pings.** In the browser's developer tools, Network tab, filter for `keepawake`. While you use the page you should see a `POST .../keepawake/ping` about once a minute. They stop about 3 minutes after you stop touching the page, or as soon as you switch to another tab.
- **The keep-awake request.** In an admin PowerShell window, run `powercfg /requests`. While the script is holding the PC awake, the `SYSTEM:` section lists `[PROCESS] ...\powershell.exe`. When it has let go, that entry is gone.
- **The log.** `Get-Content C:\ProgramData\comfyui-keepawake\keepawake.log -Tail 20` shows when the script started, whether it can reach ComfyUI, and each time it starts or stops holding the PC awake, with the reason.
- **The task.** `Get-ScheduledTask "ComfyUI keep awake" | Get-ScheduledTaskInfo` shows when it last ran. `LastTaskResult` is `267009` while it's running.

## Development

Requires [Nix](https://nixos.org) with flakes enabled and [direnv](https://direnv.net) with [nix-direnv](https://github.com/nix-community/nix-direnv).

```sh
direnv allow   # loads the dev shell and installs the pre-commit hook
just           # lists available recipes
```

| Recipe                      | What it does                                                                       |
| --------------------------- | ---------------------------------------------------------------------------------- |
| `just fmt`                  | Format every file                                                                  |
| `just lint`                 | Check for merge conflict markers and secrets                                       |
| `just test`                 | Run the tests                                                                      |
| `just check`                | Check formatting and run flake checks                                              |
| `just verify`               | Everything that must pass before merging                                           |
| `just update-template`      | Pull in changes from the project template                                          |
| `just set-automation-token` | Store the automation token from 1Password as this repo's `AUTOMATION_TOKEN` secret |

After creating the GitHub repo, run `just set-automation-token` (needs the 1Password CLI, `op`). The weekly `flake.lock` and template-update workflows use the token to open PRs that trigger CI, and to clone the template. Rerun it whenever the token is regenerated.

`just fmt` and `just lint` run automatically on commit, on the staged files. If the hook reformats files, the commit stops; `git add` the changes and commit again.
