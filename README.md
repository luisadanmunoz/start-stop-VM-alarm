# start-stop-VM-alarm
start-stop-VM-alarm

# Pasos
1.-cumplimentar /backend/start-stop-VM-alarm.tfvars
2.-cumplimentar /env/start-stop-VM-alarm.tfvars
3.- terraform init -backend-config .\backend\start-stop-VM-alarm.tfvars
4.- terraform apply -var-file="./env/start-stop-VM-alarm.tfvars"

