#!/bin/bash
gcloud auth login;
gcloud init;

echo Creating a custom VPC network
read -p "Please enter a name for your VPC network; 
  example: my-lb-network "  my-lb-network
echo "Creating VPC network with name $my-lb-network"
gcloud compute networks create $my-lb-network --subnet-mode=custom;

echo Creating subnet
read -p "Please enter a name for your subnet; example: my-subnet "  my-subnet
echo "Creating subnet with name $my-subnet"
gcloud compute networks subnets create $my-subnet \
  --network=$my-lb-network \
  --range=10.1.10.0/24 \
  --region=southamerica-east1;

echo Reserving the IP addresses
read -p "Please enter a name for your IP address; 
  example: my-lb-ipv4 "  my-lb-ipv4
echo "Creating IP address with name $my-lb-ipv4"
gcloud compute addresses create $my-lb-ipv4 \
  --ip-version=IPV4 \
  --global;

echo Creating firewall rule to allow healthchecks and incoming traffic
gcloud compute firewall-rules create my-fw-allow-health-and-proxy \
  --network=my-lb-network \
  --action=allow \
  --direction=ingress \
  --target-tags=allow-hc-and-proxy \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --rules=tcp:80,tcp:443,tcp:3000;

echo Creating firewall rule to allow SSH 
gcloud compute firewall-rules create my-fw-allow-ssh \
  --network=my-lb-network \
  --action=allow \
  --direction=ingress \
  --target-tags=allow-ssh \
  --rules=tcp:22;

echo Creating instance template
gcloud compute instance-templates create-with-container my-first-template \
  --custom-cpu=1 \
  --custom-memory=2GB \
  --boot-disk-size=20GB \
  --container-env-file=secrets.dec \
  --region=southamerica-east1 \
  --subnet=my-subnet \
  --tags=allow-hc-and-proxy,allow-ssh \
  --container-image gcr.io/my-project-id/my-image-name;

echo Creating the managed instance group
gcloud compute instance-groups managed create my-mig \
  --base-instance-name my-instance \
  --size 3 \
  --template my-first-template \
  --region southamerica-east1;

echo Creating port forwarding
gcloud compute instance-groups managed set-named-ports my-mig \
  --named-ports port3000:3000 \
  --region southamerica-east1;

echo Creating health check
gcloud compute health-checks create http my-http-check \
  --port 3000 \
  --request-path=/health_check \
  --healthy-threshold=1 \
  --unhealthy-threshold=10

echo Assigning health check to the managed instance group
gcloud compute instance-groups managed update my-mig \
  --health-check my-http-check \
  --initial-delay 300 \
  --region southamerica-east1

echo Creating a backend service
gcloud compute backend-services create my-backend-service \
  --protocol HTTP \
  --health-checks my-http-check \
  --global \
  --port-name=port3000 \
  --enable-cdn

echo Assigning instance group to the backend service
gcloud compute backend-services add-backend my-backend-service \
  --balancing-mode=UTILIZATION \
  --max-utilization=0.8 \
  --capacity-scaler=1 \
  --instance-group=my-mig \
  --instance-group-region=southamerica-east1 \
  --global

echo Creating storage bucket
gsutil mb -c standard -l southamerica-east1 -b on gs://my-bucket.example.com.br

echo Making the bucket public
gsutil iam ch allUsers:objectViewer gs://my-bucket.example.com.br

echo Configuring bucket for web
gsutil web set -m index.html -e index.html gs://my-bucket.example.com.br

echo Creating backend-bucket using our newly created buckets
gcloud compute backend-buckets create my-backend-bucket \
  --gcs-bucket-name=gs://my-bucket.example.com.br \
  --enable-cdn

echo Creating a URL map
gcloud compute url-maps create my-lb-map \
  --default-backend-bucket my-backend-bucket

echo 'Adding path matcher to the URL map (backend)'
gcloud compute url-maps add-path-matcher my-lb-map \
  --default-service my-backend-service \
  --path-matcher-name my-pathmap-backend \
  --new-hosts=my-backend.example.com.br

echo Adding path matcher to the URL map (frontend)
gcloud compute url-maps add-path-matcher my-lb-map \
  --default-backend-bucket my-backend-bucket \
  --path-matcher-name my-pathmap-frontend \
  --new-hosts=my-bucket.example.com.br

echo Creating a managed certificate 
gcloud beta compute ssl-certificates create my-mcrt \
  --domains my-bucket.example.com.br,my-backend.example.com.br

echo Creating an https proxy
gcloud compute target-https-proxies create my-https-proxy \
  --url-map my-lb-map \
  --ssl-certificates my-mcrt

echo Creating forwarding rules to proxy
gcloud compute forwarding-rules create my-forwarding-rule \
  --address=my-lb-ipv4 \
  --global \
  --target-https-proxy=my-https-proxy \
  --ports=443

echo Creating address range for db private network
gcloud compute addresses create my-sql-network-ranges \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=24 \
  --network=my-lb-network

echo Creating the VPC peering
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=my-sql-network-ranges \
  --network=my-lb-network

echo Creating db instance
gcloud beta sql instances create my-database-2 \
  --network=my-lb-network \
  --tier=db-n1-standard-1 \
  --region=southamerica-east1

