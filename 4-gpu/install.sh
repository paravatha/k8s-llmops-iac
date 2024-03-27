NVIDIA
https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html
https://github.com/NVIDIA/gpu-operator/blob/master/deployments/gpu-operator/values.yaml

kubectl create ns gpu-operator
kubectl label --overwrite ns gpu-operator pod-security.kubernetes.io/enforce=privileged
kubectl get nodes -o json | jq '.items[].metadata.labels | keys | any(startswith("feature.node.kubernetes.io"))'

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update

helm upgrade --cleanup-on-fail --install nvidia-gpu-operator nvidia/gpu-operator -n gpu-operator -f values.yaml

helm uninstall -n gpu-operator nvidia-gpu-operator

kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.5/nvidia-device-plugin.yml

AMD
https://github.com/ROCm/k8s-device-plugin

helm repo add amd-gpu-helm https://rocm.github.io/k8s-device-plugin/ && helm repo update

helm install my-amd-gpu amd-gpu-helm/amd-gpu --version 0.12.0 -f amd-values.yaml

helm upgrade --cleanup-on-fail --install my-amd-gpu amd-gpu-helm/amd-gpu --version 0.12.0 -f amd-values.yaml

helm uninstall -n kube-system my-amd-gpu