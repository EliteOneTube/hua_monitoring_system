
# Hua Monitoring System

By combining Node-red & Thingsboard we were able to monitor devices such as GPU HPC Clusters, UPS & Switches.


## Tech Stack

**ThingsBoard**

**MinIO**

**Node-Red**

**RabbitMQ**


## Installation

```bash
  git clone https://github.com/EliteOneTube/hua_monitoring_system
```
## Documentation

### Project Structure  
The project consists of multiple folders, each serving a specific role in data collection and processing.  

#### GPU Data Gathering  
There are **two folders** dedicated to GPU data collection, depending on the GPU version used. These contain scripts that gather telemetry data from the GPUs and send it to the system.  

#### Raspberry Pi with Thermometer  
A dedicated **Python script** is used for data collection from a **Raspberry Pi** equipped with a **DS18B20 temperature sensor**. The script continuously monitors the temperature and sends the data to the system.  

#### Node-Red Flows  
The **Node-Red folder** contains flows used for data retrieval, processing, and storage. The flows are structured as follows:  

1. **JWT Token Flow**  
   - Requests a **JWT token** from ThingsBoard for authentication.  

2. **Device Data Retrieval Flow**  
   - Iterates over each device inputted.  
   - Requests **keys** associated with the device.  
   - Requests **values** for those keys within a **1-day timeframe**.  
   - Processes and stores the data in **MinIO**.  

3. **SNMP Data Collection**  
   - **SNMP GET requests** are used to collect telemetry data.  
   - **UPS SNMP Flow**: Retrieves data from a **UPS (STR-5000-CENTRAL)** using SNMP.  
   - **Switch SNMP Flow**: Retrieves **network statistics and metrics** from a **Cisco switch** using SNMP.  

### Data Storage and Processing  
All collected data is processed and stored in **MinIO**, which serves as the main storage system. The combination of **Node-Red, SNMP, and ThingsBoard** ensures real-time data retrieval and monitoring of **devices, network equipment, and environmental conditions**.  
## Environment Variables

To run this project, you will need to rename the file `template.env` to `.env` and change the variables to other values. (Leaving them as they are will work but is not recommended!!!)

### Breakdown

#### RabbitMQ Configuration  
```env
RABBITMQ_DEFAULT_USER=rabbitmq_user   # Default username for RabbitMQ  
RABBITMQ_DEFAULT_PASS=rabbitmq_password   # Default password for RabbitMQ  
```

#### MinIO Configuration
```env
MINIO_ACCESS_KEY=minio_access_key   # Access key for MinIO authentication  
MINIO_SECRET_KEY=minio_secret_key   # Secret key for MinIO authentication  
MINIO_BUCKET=thingsboard   # MinIO bucket name for storing ThingsBoard data 
```

#### ThingsBoard Queue Configuration
```env
TB_QUEUE_TYPE=rabbitmq   # Defines the queue type for ThingsBoard  
TB_QUEUE_RABBIT_MQ_USERNAME=${RABBITMQ_DEFAULT_USER}   # RabbitMQ username (same as RABBITMQ_DEFAULT_USER)  
TB_QUEUE_RABBIT_MQ_PASSWORD=${RABBITMQ_DEFAULT_PASS}   # RabbitMQ password (same as RABBITMQ_DEFAULT_PASS)  
TB_QUEUE_RABBIT_MQ_HOST=rabbitmq   # RabbitMQ server hostname/IP  
TB_QUEUE_RABBIT_MQ_PORT=5672   # RabbitMQ port (default: 5672)  
```

#### Switch SNMP
```env
SWITCH_IP=   # IP address of the network switch  
SNMP_COMMUNITY=   # SNMP community string for switch data access  
THINGSBOARD_TOKEN=   # ThingsBoard access token for authentication  
THINGSBOARD_SERVER=   # ThingsBoard server URL for data transmission  
```
## Deployment

To deploy this project run

```bash
  sudo docker compose up -d
```

Once every platform is up and running

```bash
Create all the proper devices in Thingsboard
import the flows into node-red
Set up the scripts to run on your devices
```


## Authors

- [@itp24107]()
- [@itp24120](https://github.com/jtsoukalas)
- [@itp24109](https://github.com/EliteOneTube)

