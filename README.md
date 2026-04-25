# nginx-rtmp-server

Hardened nginx + nginx-rtmp-module on Kubernetes.

## Container

* Built from source on alpine, runs as non-root UID 10001.
* Read-only root filesystem; all writable paths come from `emptyDir` volumes.
* All Linux capabilities dropped, no privilege escalation, `RuntimeDefault` seccomp.

## Image build (local with buildah for CRI-O)

```bash
sudo buildah bud -t localhost/nginx-rtmp-server:dev .
sudo crictl images | grep nginx-rtmp-server
```

For Kubernetes use the GHCR image built by `.github/workflows/build.yaml`:
`ghcr.io/eumel8/nginx-rtmp-server:latest`.

## Helm install

```bash
kubectl create namespace nginx-rtmp-server
helm upgrade --install nginx-rtmp-server charts/nginx-rtmp-server \
  -n nginx-rtmp-server
```

## Exposing RTMP through ingress-nginx (cluster-scoped, do once)

ingress-nginx by default only handles HTTP(S). To forward TCP/1935 to the RTMP
service the controller needs a `tcp-services` ConfigMap and an extra port on
the controller Service.

```bash
# 1. ConfigMap pointing :1935 -> svc/nginx-rtmp-server.nginx-rtmp-server:1935
kubectl -n ingress-nginx create configmap tcp-services \
  --from-literal=1935=nginx-rtmp-server/nginx-rtmp-server:1935 \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Tell the controller to read that ConfigMap (--tcp-services-configmap arg)
kubectl -n ingress-nginx get deploy ingress-nginx-controller -o yaml \
  | grep -- --tcp-services-configmap || \
kubectl -n ingress-nginx patch deploy ingress-nginx-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-",
   "value":"--tcp-services-configmap=ingress-nginx/tcp-services"}
]'

# 3. Add port 1935 to the controller Service
kubectl -n ingress-nginx patch svc ingress-nginx-controller --type=json -p='[
  {"op":"add","path":"/spec/ports/-",
   "value":{"name":"rtmp","port":1935,"targetPort":1935,"protocol":"TCP"}}
]'
```

## Streaming

* Publish: `rtmp://rtmp.e.mcsps.de/live/<stream-key>`
* HLS:     `https://rtmp.e.mcsps.de/hls/<stream-key>.m3u8`
* DASH:    `https://rtmp.e.mcsps.de/dash/<stream-key>.mpd`
* Stats:   `https://rtmp.e.mcsps.de/stat`
