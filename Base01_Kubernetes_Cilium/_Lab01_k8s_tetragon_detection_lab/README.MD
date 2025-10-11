# Overview
A simple environment designed for creating a Tetragon detection lab using an existing Kubernetes Cluster in Proxmox Environment. This will leverage Splunk to collect the security events of Tetragon.

# What is Tetragon?
[Tetragon](https://tetragon.io/) is a flexible Kubernetes-aware security observability and runtime enforcement tool that uses eBPF (extended Berkeley Packet Filter) to provide deep visibility into system behavior. It enables real-time monitoring and detection of:

- **Process Execution**: Track process creation, arguments, and execution chains
- **File Access**: Monitor file opens, reads, writes, and modifications
- **Network Activity**: Observe network connections and traffic patterns
- **System Calls**: Capture privileged operations and system-level events
- **Kubernetes Context**: Correlate events with pods, namespaces, and container metadata

Tetragon operates at the kernel level without requiring application changes, providing transparent security observability with minimal performance overhead. It's particularly useful for detecting suspicious behavior, policy violations, and security threats in containerized environments.

# Requirements
- [Proxmox Environment](/README.md)
- [Base Kubernetes Cluster](/Base01_Kubernetes_Cilium/README.MD)
- [Splunk](https://www.splunk.com/)
  - We will not cover Splunk installation here. This guide assumes that you have an existing Splunk deployment of your choice.
  - In this lab, Splunk is the free version deployed in a Virtual Machine.
> [!Tip]
> The control plane node has "screen" installed.

# Installing Tetragon to the Kubernetes Cluster
> [!IMPORTANT]  
> Instructions here are mostly done in the **Kubernetes Control Plane**. It's best to SSH to the Control Plane Terminal.

1. Install Tetragon using Helm:
  ```bash
  helm repo add cilium https://helm.cilium.io
  helm repo update
  helm install tetragon cilium/tetragon -n kube-system
  ```
  > [!NOTE]
  > The Cilium Helm repository is already installed if you followed the Base01_Kubernetes_Cilium deployment guide.

2. Verify the Tetragon deployment status:
  ```bash
  kubectl rollout status -n kube-system ds/tetragon -w
  ```
  This command will wait and display the rollout status until all Tetragon pods are ready.

3. Verify the pods are running:
  ```bash
  kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon
  ```
  It will display something similar to this:
  ```text
  NAME             READY   STATUS    RESTARTS   AGE
  tetragon-4fs7d   2/2     Running   0          37m
  tetragon-7fbx9   2/2     Running   0          37m
  tetragon-kxptv   2/2     Running   0          37m
  tetragon-n87ht   2/2     Running   0          37m
  ```
# Configuring Splunk Integration
## Setting up Splunk HTTP Event Collector (HEC)
1. Log into your **Splunk Web Interface** and navigate to **Settings > Data Inputs > HTTP Event Collector**.
2. Click **New Token** and configure:
  - **Name**: `tetragon-events`
  - **Source type**: `_json` (Select)
  - **Index**: Create or select an index
    - kubernetes_security
  - Click **Review** and then **Submit**
3. Copy the **Token Value** (you'll need this for the next step).
4. Ensure HEC is enabled:
  - Go to **Settings > Data Inputs > HTTP Event Collector > Global Settings**
  - Check **All Tokens** is set to **Enabled**
  - Note the **HTTP Port Number** (default: 8088)

## Deploying Fluent Bit to Forward Tetragon Events
We'll use Fluent Bit as a lightweight log forwarder to send Tetragon JSON events to Splunk.
1. Create a namespace for logging:
  ```bash
  kubectl create namespace logging
  ```
2. Create a Secret with your Splunk HEC token:
  ```bash
  kubectl create secret generic splunk-hec-token \
    --from-literal=token='YOUR_SPLUNK_HEC_TOKEN' \
    -n logging
  ```
  Replace `YOUR_SPLUNK_HEC_TOKEN` with the token from Splunk.

3. Create a ConfigMap for Fluent Bit configuration.
  ```bash
  cat <<'EOF' | kubectl apply -f -
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: fluent-bit-config
    namespace: logging
  data:
    fluent-bit.conf: |
      [SERVICE]
        Flush        5
        Log_Level    info
        Parsers_File parsers.conf

      [INPUT]
        Name              tail
        Path              /var/run/cilium/tetragon/tetragon.log
        Parser            tetragon_parser
        Tag               tetragon
        Refresh_Interval  5
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   Off

      [OUTPUT]
        Name             splunk
        Match            tetragon
        Host             YOUR_SPLUNK_IP
        Port             8088
        TLS              On
        TLS.Verify       Off
        Splunk_Token      ${SPLUNK_HEC_TOKEN}
        Splunk_Send_Raw  Off
        Event_Source     fluent-bit
        Event_Sourcetype _json
    
    parsers.conf: |
      [PARSER]
        Name        tetragon_parser
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%LZ
        Time_Keep   On
  EOF
  ```
  Replace `YOUR_SPLUNK_IP` with your Splunk server IP address.

4. Deploy Fluent Bit DaemonSet:
  ```bash
  cat <<'EOF' | kubectl apply -f -
  apiVersion: apps/v1
  kind: DaemonSet
  metadata:
    name: fluent-bit
    namespace: logging
    labels:
      app: fluent-bit
  spec:
    selector:
      matchLabels:
        app: fluent-bit
    template:
      metadata:
        labels:
          app: fluent-bit
      spec:
        serviceAccountName: fluent-bit
        containers:
        - name: fluent-bit
          image: fluent/fluent-bit:4.1.1
          env:
          - name: SPLUNK_HEC_TOKEN
            valueFrom:
              secretKeyRef:
                name: splunk-hec-token
                key: token
          volumeMounts:
          - name: varlog
            mountPath: /var/run/cilium/tetragon
            readOnly: true
          - name: fluent-bit-config
            mountPath: /fluent-bit/etc/
        volumes:
        - name: varlog
          hostPath:
            path: /var/run/cilium/tetragon
        - name: fluent-bit-config
          configMap:
            name: fluent-bit-config
  ---
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: fluent-bit
    namespace: logging
  EOF
  ```

5. Verify Fluent Bit is running:
  ```bash
  kubectl get pods -n logging -l app=fluent-bit
  ```
  You should see Fluent Bit pods running on each worker node:
  ```text
  NAME               READY   STATUS    RESTARTS   AGE
  fluent-bit-csjqf   1/1     Running   0          20m
  fluent-bit-hbs8w   1/1     Running   0          20m
  fluent-bit-q7c5t   1/1     Running   0          20m
  ```
  It's also best to see the logs if issues are encountered.
  ```bash
  kubectl logs -n logging fluent-bit-q7c5t
  ```
  ```text  
  Fluent Bit v4.1.1
  * Copyright (C) 2015-2025 The Fluent Bit Authors
  * Fluent Bit is a CNCF sub-project under the umbrella of Fluentd
  * https://fluentbit.io

  ______ _                  _    ______ _ _             ___   __
  |  ___| |                | |   | ___ (_) |           /   | /  |
  | |_  | |_   _  ___ _ __ | |_  | |_/ /_| |_  __   __/ /| | `| |
  |  _| | | | | |/ _ \ '_ \| __| | ___ \ | __| \ \ / / /_| |  | |
  | |   | | |_| |  __/ | | | |_  | |_/ / | |_   \ V /\___  |__| |_
  \_|   |_|\__,_|\___|_| |_|\__| \____/|_|\__|   \_/     |_(_)___/


  [2025/10/10 07:51:19.808812265] [ info] [fluent bit] version=4.1.1, commit=912b7d783a, pid=1
  [2025/10/10 07:51:19.808869583] [ info] [storage] ver=1.5.3, type=memory, sync=normal, checksum=off, max_chunks_up=128
  [2025/10/10 07:51:19.808874019] [ info] [simd    ] SSE2
  [2025/10/10 07:51:19.808876601] [ info] [cmetrics] version=1.0.5
  [2025/10/10 07:51:19.808878982] [ info] [ctraces ] version=0.6.6
  [2025/10/10 07:51:19.808945175] [ info] [input:tail:tail.0] initializing
  [2025/10/10 07:51:19.808949113] [ info] [input:tail:tail.0] storage_strategy='memory' (memory only)
  [2025/10/10 07:51:19.812074575] [ info] [output:splunk:splunk.0] worker #0 started
  [2025/10/10 07:51:19.812281803] [ info] [sp] stream processor started
  [2025/10/10 07:51:19.812464883] [ info] [engine] Shutdown Grace Period=5, Shutdown Input Grace Period=2
  [2025/10/10 07:51:19.812672324] [ info] [input:tail:tail.0] inotify_fs_add(): inode=2228 watch_fd=1 name=/var/run/cilium/tetragon/tetragon.log
  [2025/10/10 07:51:19.815375890] [ info] [output:splunk:splunk.0] worker #1 started
```
## Verifying Events in Splunk
> [!IMPORTANT]  
> Tetragon comes with default Process Execution Monitoring Policy, Your Splunk should ingest the fluentbit operations made as a daemonset.

1. Log into Splunk and go to **Search & Reporting**.
2. Run a search query to verify Tetragon events are being received:
  ```spl
  index=kubernetes_security sourcetype=_json
  ```
  ![splunk_verify](/Base01_Kubernetes_Cilium/_Lab01_k8s_tetragon_detection_lab/assets/splunk_verify_flow.png)
