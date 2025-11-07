# meshcoretomqtt

A Python-based script to send MeshCore debug and packet capture data to MQTT for
analysis. Requires a MeshCore repeater to be connected to a Raspberry Pi,
server, or similar device running Python.

The goal is to have multiple repeaters logging data to the same MQTT server so
you can easily troubleshoot packets through the mesh. You will need to build a
custom image with packet logging and/or debug for your repeater to view the
data.

One way of tracking a message through the mesh is filtering the MQTT data on the
hash field as each message has a unique hash. You can see which repeaters the
message hits!

## Quick Install

### One-Line Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Cisien/meshcoretomqtt/main/install.sh | bash
```

### Pre-Configuration from URL

Use a hosted configuration file for quick setup:

```bash
# Example: Local broker + LetsMesh.net Packet Analyzer MQTT server
curl -fsSL https://raw.githubusercontent.com/Cisien/meshcoretomqtt/main/install.sh | \
  bash -s -- --config https://gist.githubusercontent.com/username/abc123/raw/my-config.env
```

This is useful for deploying multiple nodes with the same configuration.

### Custom Configuration URL

Use your own configuration (Gist, repo, etc.):

```bash
curl -fsSL https://raw.githubusercontent.com/Cisien/meshcoretomqtt/main/install.sh | \
  bash -s -- --config https://gist.githubusercontent.com/username/abc123/raw/my-config.env
```

### Custom Repository/Branch

Install from a fork or custom branch:

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/meshcoretomqtt/yourbranch/install.sh | \
  bash -s -- --repo yourusername/meshcoretomqtt --branch yourbranch
```

The installer will:

- Guide you through interactive configuration (or use provided config)
- Set up Python virtual environment
- Configure one or multiple MQTT brokers
- Choose installation method: system service, Docker container, or manual
- Handle both Linux (systemd) and macOS (launchd)
- Auto-detect and update existing installations

### Local Testing

If you want to test the installer locally:

```bash
git clone https://github.com/Cisien/meshcoretomqtt
cd meshcoretomqtt
LOCAL_INSTALL=$(pwd) ./install.sh
```

### NixOS

Use this flake with NixOS this way.

flake.nix

```nix
inputs = {
  meshcoretomqtt.url = "github:github.com/Cisien/meshcoretomqtt"
};
```

in your system config

```nix
imports = [inputs.meshcoretomqtt.nixosModules.default];
services.mctomqtt = {
    enable = true;
    iata = "FOO";
    serialPorts = ["/dev/ttyUSB0"];

    # Disable defaults if you like.
    # Defaults are use if nothing is specified
    defaults = {
        letsmesh-us.enable = true;
        letsmesh-eu.enable = true;
    };

    # Define custom brokers if you need them
    brokers = [
      {
        enabled = true;
        server = "mqtt.example.com";
        port = 1883;
        use-tls = true;
        use-auth-token = true;
        username = "my_username";
        password = "my_password";
      }
    ];

    # Additional settings
    # foo-bar becomes MCTOMQTT_FOO_BAR
    settings = {
      log-level = "DEBUG";
    };
  };
```

## Prerequisites

### Hardware Setup

1. Setup a Raspberry Pi (Zero / 2 / 3 or 4 recommended) or similar Linux/macOS
   device
2. Build/flash a MeshCore repeater with appropriate build flags:

   **Recommended minimum:**
   ```
   -D MESH_PACKET_LOGGING=1
   ```

   **Optional debug data:**
   ```
   -D MESH_DEBUG=1
   ```

3. Plug the repeater into the device via USB (RAK or Heltec tested)
4. Configure the repeater with a unique name as per MeshCore guides

### Software Requirements

- Python 3.7 or higher
- For auth token support (optional): Node.js and `@michaelhart/meshcore-decoder`

The installer handles these dependencies automatically!

## Configuration

Configuration uses environment files (`.env` and `.env.local`):

- `.env` - Contains default values (don't edit, will be overwritten on updates)
- `.env.local` - Your custom configuration (gitignored, never overwritten)

### Manual Configuration

If you need to manually edit configuration after installation:

```bash
# Edit your local configuration
nano ~/.meshcoretomqtt/.env.local
```

#### Basic Example (.env.local)

```bash
# Serial Configuration
SERIAL_PORTS=/dev/ttyACM0

# Global IATA Code (3-letter airport code for your location)
IATA=SEA

# MQTT Broker 1 - Username/Password
MQTT1_ENABLED=true
MQTT1_SERVER=mqtt.example.com
MQTT1_PORT=1883
MQTT1_USERNAME=my_username
MQTT1_PASSWORD=my_password
```

#### Advanced Example with Multiple Brokers

```bash
# Serial Configuration
SERIAL_PORTS=/dev/ttyACM0
IATA=SEA

# Broker 1 - Local MQTT with Username/Password
MQTT1_ENABLED=true
MQTT1_SERVER=mqtt.local
MQTT1_PORT=1883
MQTT1_USERNAME=localuser
MQTT1_PASSWORD=localpass

# Broker 2 - Public Observer Network with Auth Token
MQTT2_ENABLED=true
MQTT2_SERVER=mqtt-us-v1.letsmesh.net
MQTT2_PORT=443
MQTT2_TRANSPORT=websockets
MQTT2_USE_TLS=true
MQTT2_USE_AUTH_TOKEN=true
MQTT2_TOKEN_AUDIENCE=mqtt-us-v1.letsmesh.net
```

### Topic Templates

Topics support template variables:

- `{IATA}` - Your 3-letter location code
- `{PUBLIC_KEY}` - Device public key (auto-detected)

**Global topics** (apply to all brokers by default):

```bash
TOPIC_STATUS=meshcore/{IATA}/{PUBLIC_KEY}/status
TOPIC_PACKETS=meshcore/{IATA}/{PUBLIC_KEY}/packets
TOPIC_DEBUG=meshcore/{IATA}/{PUBLIC_KEY}/debug
TOPIC_RAW=meshcore/{IATA}/{PUBLIC_KEY}/raw
```

**Per-broker topic overrides** (optional):

```bash
# Broker 2 uses different topic structure
MQTT2_TOPIC_STATUS=custom/{IATA}/{PUBLIC_KEY}/status
MQTT2_TOPIC_PACKETS=custom/{IATA}/{PUBLIC_KEY}/data
MQTT2_IATA=LAX  # Different IATA code for this broker
```

This allows sending the same data to multiple brokers with different topic
structures.

## Authentication Methods

### 1. Username/Password

```bash
MQTT1_ENABLED=true
MQTT1_SERVER=mqtt.example.com
MQTT1_USERNAME=your_username
MQTT1_PASSWORD=your_password
```

### 2. Auth Token (Public Key Based)

Requires `@michaelhart/meshcore-decoder` and firmware supporting `get prv.key`
command.

```bash
MQTT1_ENABLED=true
MQTT1_SERVER=mqtt-us-v1.letsmesh.net
MQTT1_USE_AUTH_TOKEN=true
MQTT1_TOKEN_AUDIENCE=mqtt-us-v1.letsmesh.net
```

The script will:

- Read the private key from the connected MeshCore device via serial
- Generate JWT auth tokens using the device's private key
- Authenticate using the `v1_{PUBLIC_KEY}` username format

**Note:** The private key is read directly from the device and used for signing
only. It's never transmitted or saved to disk.

To install meshcore-decoder:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# Restart shell or: source ~/.bashrc
nvm install --lts
npm install -g @michaelhart/meshcore-decoder
```

## Running the Script

The installer offers three deployment options:

### 1. System Service (Recommended)

Automatically starts on boot and runs in the background.

**Linux (systemd):**

```bash
sudo systemctl start mctomqtt      # Start service
sudo systemctl stop mctomqtt       # Stop service
sudo systemctl status mctomqtt     # Check status
sudo systemctl restart mctomqtt    # Restart service
sudo journalctl -u mctomqtt -f     # View logs
```

**macOS (launchd):**

```bash
launchctl start com.meshcore.mctomqtt    # Start service
launchctl stop com.meshcore.mctomqtt     # Stop service
launchctl list | grep mctomqtt           # Check status
tail -f ~/Library/Logs/mctomqtt.log      # View logs
```

### 2. Docker Container

Isolated containerized deployment with automatic restarts.

#### Manual Docker Setup

If you prefer to run Docker manually without the installer:

```bash
# Build the image
docker build -t mctomqtt:latest /path/to/meshcoretomqtt

# Run the container
docker run -d \
  --name mctomqtt \
  --restart unless-stopped \
  -v ~/.meshcoretomqtt/.env.local:/opt/.env.local \
  --device=/dev/ttyACM0 \
  mctomqtt:latest
```

### 3. Manual Execution

Run directly without service management.

```bash
cd ~/.meshcoretomqtt
./venv/bin/python3 mctomqtt.py
```

With debug output:

```bash
./venv/bin/python3 mctomqtt.py -debug
```

## Updates

### Automatic Updates

Simply re-run the installer - it will detect your existing installation and
offer to update:

```bash
curl -fsSL https://raw.githubusercontent.com/Cisien/meshcoretomqtt/main/install.sh | bash
```

Or for non-interactive updates (useful for scripts/automation):

```bash
curl -fsSL https://raw.githubusercontent.com/Cisien/meshcoretomqtt/main/install.sh | bash -s -- --update
```

The updater will:

- Detect your existing service type (systemd/launchd/Docker)
- Stop the service/container
- Download and verify updated files
- Preserve your `.env.local` configuration
- Restart the service/container automatically

### Custom Repository Updates

Install from a specific repo/branch:

```bash
# Using environment variables
INSTALL_REPO=yourusername/meshcoretomqtt INSTALL_BRANCH=yourbranch bash <(curl -fsSL https://raw.githubusercontent.com/yourusername/meshcoretomqtt/yourbranch/install.sh)

# Or using flags
curl -fsSL https://raw.githubusercontent.com/yourusername/meshcoretomqtt/yourbranch/install.sh | \
  bash -s -- --repo yourusername/meshcoretomqtt --branch yourbranch
```

### Local Updates

If you've cloned the repository:

```bash
cd meshcoretomqtt
LOCAL_INSTALL=$(pwd) ./install.sh
```

## Reconfiguration

To reconfigure without updating, either:

1. **Interactive:** Re-run the installer and select "Reconfigure" when prompted
2. **Manual:** Edit `.env.local` directly and restart the service:
   ```bash
   nano ~/.meshcoretomqtt/.env.local
   # Then restart: sudo systemctl restart mctomqtt (or docker restart mctomqtt)
   ```

## Uninstallation

```bash
curl -fsSL https://raw.githubusercontent.com/Cisien/meshcoretomqtt/main/uninstall.sh | bash
```

Or locally:

```bash
cd ~/.meshcoretomqtt
./uninstall.sh
```

The uninstaller will:

- Stop and remove the service
- Offer to backup your `.env.local`
- Prompt before removing configuration
- Clean up all installed files

## Manual Docker Installation

The installer can set up Docker automatically (option 2 during installation).
For manual Docker setup:

1. Create a configuration directory:

```bash
mkdir -p ~/mctomqtt-config
```

2. Create your `.env.local` in the config directory:

```bash
cat > ~/mctomqtt-config/.env.local << 'EOF'
MCTOMQTT_SERIAL_PORTS=/dev/ttyACM0
MCTOMQTT_IATA=SEA
MCTOMQTT_MQTT1_ENABLED=true
MCTOMQTT_MQTT1_SERVER=mqtt.example.com
MCTOMQTT_MQTT1_USERNAME=user
MCTOMQTT_MQTT1_PASSWORD=pass
EOF
```

3. Build and run:

```bash
docker build -t mctomqtt:latest .
docker run -d --name mctomqtt \
  -v ~/mctomqtt-config/.env.local:/opt/.env.local \
  --device=/dev/ttyACM0 \
  --restart unless-stopped \
  mctomqtt:latest
```

Note: Instead of `/dev/ttyACM0` or similar, you can run
`ls /dev/serial/by-id/ -al` to find the correct device and a more consistent
device reference.

4. View logs:

```bash
docker logs -f mctomqtt
```

**Note:** The installer handles all of this automatically, including interactive
configuration!

## Privacy

This tool collects and forwards all packets transmitted over the MeshCore
network. MeshCore does not currently have any privacy controls baked into the
protocol to designate whether a user would like their data logged
([#435](https://github.com/ripplebiz/MeshCore/issues/435)). Privacy on MeshCore
is provided by protecting secret channel keys - only packets encrypted with
known channel keys can be decrypted and read. Packets on channels where you
don't have the key will be forwarded as encrypted data.

## Viewing the data

- Use a MQTT tool to view the packet data.

  I recommend MQTTX
- Data will appear in the following topics...
  ```
  TOPIC_STATUS = "meshcore/status"
  TOPIC_RAW = "meshcore/raw"
  TOPIC_DEBUG = "meshcore/debug"
  TOPIC_PACKETS = "meshcore/packets"
  TOPIC_DECODED = "meshcore/decoded"
  ```
  Status: The last will and testement (LWT) of each node connected. Here you can
  see online / offline status of a node on the MQTT server.

  RAW: The raw packet data going through the repeater.

  DEBUG: The debug info (if enabled on the repeater build)

  PACKETS: The flood or direct packets going through the repeater.

  DECODED: Packets are decoded (and decrypted when the key is known) and
  pubished to this topic as unencrypted JSON

## Example MQTT data...

Note: origin is the repeater node reporting the data to mqtt. Not the origin of
the LoRa packet.

Flood packet...

```
Topic: meshcore/packets QoS: 0
{"origin": "ag loft rpt", "timestamp": "2025-03-16T00:07:11.191561", "type": "PACKET", "direction": "rx", "time": "00:07:09", "date": "16/3/2025", "len": "87", "packet_type": "5", "route": "F", "payload_len": "83", "SNR": "4", "RSSI": "-93", "score": "1000", "hash": "AC9D2DDDD8395712"}
```

Direct packet...

```
Topic: meshcore/packets QoS: 0
{"origin": "ag loft rpt", "timestamp": "2025-03-15T23:09:00.710459", "type": "PACKET", "direction": "rx", "time": "23:08:59", "date": "15/3/2025", "len": "22", "packet_type": "2", "route": "D", "payload_len": "20", "SNR": "5", "RSSI": "-93", "score": "1000", "hash": "890BFA3069FD1250", "path": "C2 -> E2"}
```

## ToDo

- Complete more thorough testing
- Fix bugs with keepalive status topic
