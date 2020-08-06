gcloud auth login;
gcloud init;

print Creating a custom VPC network
gcloud compute networks create my-lb-network --subnet-mode=custom;

print Creating subnet
gcloud compute networks subnets create my-subnet \
  --network=my-lb-network \
  --range=10.1.10.0/24 \
  --region=southamerica-east1;

print Reserving the IP addresses
gcloud compute addresses create my-lb-ipv4 \
  --ip-version=IPV4 \
  --global;

print Creating firewall rule to allow healthchecks and incoming traffic
gcloud compute firewall-rules create my-fw-allow-health-and-proxy \
  --network=my-lb-network \
  --action=allow \
  --direction=ingress \
  --target-tags=allow-hc-and-proxy \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --rules=tcp:80,tcp:443,tcp:3000;

print Creating firewall rule to allow SSH 
gcloud compute firewall-rules create my-fw-allow-ssh \
  --network=my-lb-network \
  --action=allow \
  --direction=ingress \
  --target-tags=allow-ssh \
  --rules=tcp:22;

print Creating instance template
gcloud compute instance-templates create-with-container my-first-template \
  --custom-cpu=1 \
  --custom-memory=2GB \
  --boot-disk-size=20GB \
  --container-env-file=secrets.dec \
  --region=southamerica-east1 \
  --subnet=my-subnet \
  --tags=allow-hc-and-proxy,allow-ssh \
  --container-image gcr.io/my-project-id/my-image-name;

print Creating the managed instance group
gcloud compute instance-groups managed create my-mig \
  --base-instance-name my-instance \
  --size 3 \
  --template my-first-template \
  --region southamerica-east1;

print Creating port forwarding
gcloud compute instance-groups managed set-named-ports my-mig \
  --named-ports port3000:3000 \
  --region southamerica-east1;

print Creating health check
gcloud compute health-checks create http my-http-check \
  --port 3000 \
  --request-path=/health_check \
  --healthy-threshold=1 \
  --unhealthy-threshold=10

print Assigning health check to the managed instance group
gcloud compute instance-groups managed update my-mig \
  --health-check my-http-check \
  --initial-delay 300 \
  --region southamerica-east1

print Creating a backend service
gcloud compute backend-services create my-backend-service \
  --protocol HTTP \
  --health-checks my-http-check \
  --global \
  --port-name=port3000 \
  --enable-cdn

print Assigning instance group to the backend service
gcloud compute backend-services add-backend my-backend-service \
  --balancing-mode=UTILIZATION \
  --max-utilization=0.8 \
  --capacity-scaler=1 \
  --instance-group=my-mig \
  --instance-group-region=southamerica-east1 \
  --global

print Creating storage bucket
gsutil mb -c standard -l southamerica-east1 -b on gs://my-bucket.example.com.br

print Making the bucket public
gsutil iam ch allUsers:objectViewer gs://my-bucket.example.com.br

print Configuring bucket for web
gsutil web set -m index.html -e index.html gs://my-bucket.example.com.br

print Creating backend-bucket using our newly created buckets
gcloud compute backend-buckets create my-backend-bucket \
  --gcs-bucket-name=gs://my-bucket.example.com.br \
  --enable-cdn

print Creating a URL map
gcloud compute url-maps create my-lb-map \
  --default-backend-bucket my-backend-bucket

print Adding path matcher to the URL map (backend)
gcloud compute url-maps add-path-matcher my-lb-map \
  --default-service my-backend-service \
  --path-matcher-name my-pathmap-backend \
  --new-hosts=my-backend.example.com.br

print Adding path matcher to the URL map (frontend)
gcloud compute url-maps add-path-matcher my-lb-map \
  --default-backend-bucket my-backend-bucket \
  --path-matcher-name my-pathmap-frontend \
  --new-hosts=my-bucket.example.com.br

print Creating a managed certificate 
gcloud beta compute ssl-certificates create my-mcrt \
  --domains my-bucket.example.com.br,my-backend.example.com.br

print Creating an https proxy
gcloud compute target-https-proxies create my-https-proxy \
  --url-map my-lb-map \
  --ssl-certificates my-mcrt

print Creating forwarding rules to proxy
gcloud compute forwarding-rules create my-forwarding-rule \
  --address=my-lb-ipv4 \
  --global \
  --target-https-proxy=my-https-proxy \
  --ports=443

print Creating address range for db private network
gcloud compute addresses create my-sql-network-ranges \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=24 \
  --network=my-lb-network

print Creating the VPC peering
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=my-sql-network-ranges \
  --network=my-lb-network

print Creating db instance
gcloud beta sql instances create my-database-2 \
  --network=my-lb-network \
  --tier=db-n1-standard-1 \
  --region=southamerica-east1

