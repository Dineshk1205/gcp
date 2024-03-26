
#GCP CLOUD Detailes 

PROJECT_ID=
GCP_ACCOUNT=
BILL_ACCOUNT_ID=
#vCENTER Detailes

VCENTER_SERVER_ADDRESS=
VCENTER_USERNAME=
VCENTER_PASSWORD=
VCENTER_DC=
VCENTER_DATASTORE=
VCENTER_CLUSTER=
VCENTER_NETWORK=
VCENTER_FOLDER=
VCENTER_RESOURCEPOOL=

#ADMIN WORKSTATION VM NETWORK CONFIGURATION DETAILES

ADMIN_WORKSTATION_IP=
ADMIN_WORKSTATION_GATEWAY=
ADMIN_WORKSTATION_NETMASK=
ADMIN_WORKSTATION_DNS=
NTP_SERVER=

# Instllaling the gcloud CLI

mkdir anthos
cd anthos
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-469.0.0-linux-x86_64.tar.gz
tar -xf google-cloud-cli-469.0.0-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh
source /root/.bashrc
source /root/anthos/google-cloud-sdk/path.bash.inc
source /root/anthos/google-cloud-sdk/completion.bash.inc

# Installaling  the anthos-auth and kubectl components

gcloud components install kubectl 
gcloud components install anthos-auth 

# Login to GCP loud 

gcloud auth login

# Creating the new project

gcloud projects create $PROJECT_ID

# Set Default Project as newly created project 

set the default $PROJECT_ID

# Link bill Account 

gcloud beta billing projects link $PROJECT_ID --billing-account=$BILL_ACCOUNT_ID

# Grating the Required permissions

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ACCOUNT" \
    --role="roles/resourcemanager.projectIamAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ACCOUNT" \
    --role="roles/serviceusage.serviceUsageAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ACCOUNT" \
    --role="roles/iam.serviceAccountCreator"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$GCP_ACCOUNT" \
    --role="roles/iam.serviceAccountKeyAdmin"


# Enabling  the required APIs in the Google Cloud project
gcloud services enable --project $PROJECT_ID \
    anthos.googleapis.com \
    container.googleapis.com \
    gkehub.googleapis.com \
    gkeconnect.googleapis.com \
    connectgateway.googleapis.com \
    monitoring.googleapis.com \
    kubernetesmetadata.googleapis.com \
    logging.googleapis.com \
    opsconfigmonitoring.googleapis.com \
    serviceusage.googleapis.com \
    iam.googleapis.com \
    cloudresourcemanager.googleapis.com \
    gkeonprem.googleapis.com \
    anthosaudit.googleapis.com \
    storage.googleapis.com

# Creating the  Component access service account  and Grating the requied permissions

gcloud iam service-accounts create component-access-sa \
    --display-name "Component Access Service Account" \
    --project $PROJECT_ID

gcloud iam service-accounts keys create component-access-key.json \
   --iam-account component-access-sa@$PROJECT_ID.iam.gserviceaccount.com


gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:component-access-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/serviceusage.serviceUsageViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:component-access-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/iam.roleViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:component-access-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/iam.serviceAccountViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:component-access-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/compute.viewer"


# Creating the Audit Service account (Optional)


#gcloud iam service-accounts create audit-logging-sa \
#  --project $PROJECT_ID
#gcloud iam service-accounts keys create audit-logging-key.json \
#  --iam-account serviceAccount:audit-logging-sa@$PROJECT_ID.iam.gserviceaccount.com

# Instllating the gkeadmin command-line Tool 

gsutil cp gs://gke-on-prem-release/gkeadm/1.28.300-gke.123/linux/gkeadm ./
chmod +x gkeadm

#Getting your vCenter CA root certificate

curl -k "https://$VCENTER_SERVER_ADDRESS/certs/download.zip" > download.zip
sudo apt-get install unzip -y 
unzip download.zip
cp certs/lin/*.0 vcenter-ca-cert.pem


# Create vCenter Credential file 

cat > credential.yaml  << EOF

apiVersion: v1
kind: CredentialFile
# list of credentials
items:
# reference name for this credential entry
- name: vCenter
  username: "$VCENTER_USERNAME"
  password: "$VCENTER_PASSWORD"

EOF

# Create admin-ws-config.yaml file for deploying the admin node 

cat > admin-ws-config.yaml  << EOF

gcp:
  # Path of the component access service account's JSON key file
  componentAccessServiceAccountKeyPath: "component-access-key.json"
# Specify which vCenter resources to use
vCenter:
  # The credentials and address GKE On-Prem should use to connect to vCenter
  credentials:
    address: "$VCENTER_SERVER_ADDRESS"
    # reference to vCenter credentials file
    fileRef:
      # read credentials from this file
      path: credential.yaml
      # entry in the credential file
      entry: vCenter
  datacenter: "$VCENTER_DC"
  datastore: "$VCENTER_DATASTORE"
  cluster: "$VCENTER_CLUSTER"
  network: "$VCENTER_NETWORK"
  # vSphere vm folder to deploy vms into. defaults to datacenter top level folder
  folder: "$VCENTER_FOLDER"
  resourcePool: "$VCENTER_RESOURCEPOOL"
  # Provide the path to vCenter CA certificate pub key for SSL verification
  caCertPath: "vcenter-ca-cert.pem"
# The URL of the proxy for the jump host
proxyUrl: ""
adminWorkstation:
  name: gke-admin-ws-240324-085232
  cpus: 4
  memoryMB: 8192
  # The boot disk size of the admin workstation in GB. It is recommended to use a
  # disk with at least 100 GB to host images decompressed from the bundle.
  diskGB: 100
  # Name for the persistent disk to be mounted to the home directory (ending in .vmdk).
  # Any directory in the supplied path must be created before deployment.
  dataDiskName: gke-on-prem-admin-workstation-data-disk/gke-admin-ws-240324-085232-data-disk.vmdk
  # The size of the data disk in MB.
  dataDiskMB: 512
  network:
    # The IP allocation mode: 'dhcp' or 'static'
    ipAllocationMode: "static"
    # # The host config in static IP mode. Do not include if using DHCP
    hostConfig:
    #   # The IPv4 static IP address for the admin workstation
      ip: "$ADMIN_WORKSTATION_IP"
    #   # The IP address of the default gateway of the subnet in which the admin workstation
    #   # is to be created
      gateway: "$ADMIN_WORKSTATION_GATEWAY"
    #   # The subnet mask of the network where you want to create your admin workstation
    #   # (e.g. 255.255.255.0)
      netmask: "$ADMIN_WORKSTATION_NETMASK"
    #   # The list of DNS nameservers to be used by the admin workstation
      dns:
      - "$ADMIN_WORKSTATION_DNS"
  # The URL of the proxy for the admin workstation
  proxyUrl: ""
  ntpServer: $NTP_SERVER

EOF

./gkeadm create admin-workstation --auto-create-service-accounts

ssh -i /root/.ssh/gke-admin-workstation ubuntu@$ADMIN_WORKSTATION_IP -o StrictHostKeyChecking=no
