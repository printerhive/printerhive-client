![Printerhive]([https://example.com/image.jpg](https://example.com/image.jpg](https://app.printerhive.com/build/media/logos/printerhive_dark.svg))

# Printerhive Client
This repository contains the PrinterHive client application. It connects your 3D printers to the PrinterHive service, allowing for remote monitoring and control.

There are several ways to install and run the client:

## 1. Automated Installation Script (Recommended for most users)

This is the easiest way to get started. The script will automatically install Docker and Docker Compose (if not already present) and set up the client.

#### Option A: Provide the API key directly
```bash
curl -fsSL https://app.printerhive.com/install -o install.sh && chmod +x install.sh && ./install.sh YOUR_CLIENT_API_KEY
```
#### Option B: Script prompts for the API key
```bash
curl -fsSL https://app.printerhive.com/install -o install.sh && chmod +x install.sh && ./install.sh
```
*(The script will ask for your Client API Key. You can find it on the PrinterHive web app.)*


## 2. Manual Installation with Docker Compose

For users who prefer manual control or want to integrate into an existing Docker setup.

1. Clone or download this repository, or simply create the necessary files (docker-compose.yml, .env, printers.json) in a new directory.
2. Obtain your Client API Key from the PrinterHive web app.
3. Configure the environment:
   - Edit the .env file and replace YOUR_CLIENT_API_KEY with your actual key:
   ```dotenv
    API_TOKEN=YOUR_CLIENT_API_KEY
    API_DOMAIN=printerhive.com
    API_HOST=https://app.printerhive.com
    ```
   - *(Note: API_DOMAIN and API_HOST must not be changed.)*
   - The printers.json file can remain as is; the client will manage printer configurations automatically after the first run.
4. Run the client:
    ```bash
    docker-compose up -d
    ```
## 3. Using the Pre-built Docker Image
You can pull and use the image directly in your own Docker setup or compose files.
Pull the image:
```bash
docker pull ghcr.io/printerhive/printerhive-client:latest
```

# Supported Architectures:

- linux/amd64 (Intel/AMD 64-bit CPUs)
- linux/arm64 (ARM 64-bit CPUs, e.g., Apple Silicon M1/M2, Raspberry Pi 4/5 running 64-bit OS)
- linux/arm/v7 (ARM 32-bit CPUs, e.g., Raspberry Pi 2/3/4 running 32-bit OS)
#### Common Devices:

- x86/x64 PCs/Servers: Most desktops, laptops, and servers running Intel or AMD processors.
- Raspberry Pi 4 Model B, Raspberry Pi 5: Running the 64-bit version of Raspberry Pi OS or compatible distributions.
- Raspberry Pi 2 Model B, Raspberry Pi 3 Model B, Raspberry Pi Zero W, Raspberry Pi Zero 2 W: Running the 32-bit version of Raspberry Pi OS or compatible distributions.
- Apple Silicon Macs (M1, M2, etc.): When running Docker Desktop.

Ensure your Docker environment supports the architecture of your device.

#### Important: When running the image directly, you must provide the environment variables (API_TOKEN, API_DOMAIN, API_HOST) and mount the necessary configuration files (.env, printers.json) as volumes, as shown in the Docker Compose.
