---
layout: post
slug: single-fluentd-log-stream-per-kubernetes-service
redirect_from:
  - /blog/single-fluentd-log-stream-per-kubernetes-service/
---

In this blog post I show you how to create a single fluentd log stream per kubernetes micro service in AWS CloudWatch.

I was setting up logging for a kubernetes cluster (Amazon EKS) with fluentd. After I followed the tutorial provided by AWS, I found that the log streams showing in AWS CloudWatch are per container per pod. That means that you cannot see all the logs of a service in one place, because you have your logs from one service distributed over multiple log streams.

Being new to working with fluentd, it took me quite some time to change the configuration, so that you have all the logs of one service unified in a log stream, which, I think, makes much more sense as a default config. This blog post shows, how to do it.


## By default Fluentd creates one log stream per container per pod

If you follow the tutorial on how to set up CloudWatch logging for your AWS EKS cluster with fluentd, which is provided here in the AWS documentation[^1], you end up with a fluentd configuration that creates one log stream per container per pod. This has some unpractical implications. E.g. if you restart a pod, the logs of the newly created pod will end up in a separate log stream, as the new pod will get a new id. In CloudWatch it looks like this (it’s just one service called “scraper-worker”, with one replica, but after several restarts, the logs end up in different places):

![fluentd one log stream per log](/assets/images/fluentd-one-per-pod2.png)
*One fluentd log stream per container per pod in AWS Cloudwatch – hard to read*

## How to create a Fluentd log stream for each k8s micro service

You can adapt the fluentd configuration, so that it creates a log stream per service.

For this edit your `fluentd.yaml` (e.g. the one that is linked in the AWS documentation) and, in the part that corresponds to the fluentd ConfigMap, find the line where the stream_name record of your container logs is set.

Here you can change the `stream_name`, which is currently set to `${tag_parts[3]}`. We want to change it to the service name, because it needs to stay constant over pod restarts. For this we can use the `container_name` of the docker image. This placeholder is provided by the fluentd kubernetes metadata plugin[^2], which by default is enabled in the configuration from the AWS documentation. We can access the `container_name` placeholder with `${record["kubernetes"]["container_name"]}`. We also need to set `enable_ruby` to true, as described in this issue of the metadata plugin[^3].

The whole part you need to change now looks like this:


```
<filter **>
  @type record_transformer
  @id filter_containers_stream_transformer
  enable_ruby true
  <record>
    stream_name ${record["kubernetes"]["container_name"]}
  </record>
</filter>
```


## Log files in k8s

As you have seen, by default the `stream_name` was set to `${tag_parts[3]}`. `${tag_parts[3]}` selects the 4th part of the tag of the log, which results in the long stream name that we see on the screenshot, e.g. `fluentd-cloudwatch-25xcb_amazon-cloudwatch_fluentd-cloudwatch-421aee3d54acbe6be47ac140cc88a71934efc945451963b7b210294e203a740e`.

The whole tag is even a bit longer and corresponds to the path and file name of the log file. Kubernetes places the log files for each docker container of each pod in `/var/log/containers` on one of the nodes. As fluentd collects these files, it separates the path and filename by dots, which, for example, leads to the complete tag var.log.containers.`fluentd-cloudwatch-25xcb_amazon-cloudwatch_fluentd-cloudwatch-421aee3d54acbe6be47ac140cc88a71934efc945451963b7b210294e203a740e.log`.

As we can see, the 4th part of the tag (selected by `tag_parts[3]`) consists of `<pod-name>_<namespace>_<container-name-container-id>`. The container-name without the container-id is the part that stays the same for all the services that use the same docker image. That’s why it makes sense to use that as the log stream tag.

## One log stream per service in AWS CloudWatch


After you have changed the `stream_name` in `fluentd.yaml`, apply the configmap and restart the pods.

`kubectl apply -f fluentd.yaml`

`kubectl -n <namespace-of-fluentd-pods> delete pod <pod-names>`


Now you have a single fluentd log stream per kubernetes service in AWS CloudWatch. The logs in AWS CloudWatch look much cleaner. All the logs of every service are in one place, in one log stream, even if we restart pods or have multiple replicas.

![fluentd one log stream per log](/assets/images/fluentd-one-per-pod2.png)
*One fluentd log stream per service in AWS CloudWatch – so much cleaner!*

[^1]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs.html
[^2]: https://github.com/fabric8io/fluent-plugin-kubernetes_metadata_filter
[^3]: https://github.com/fabric8io/fluent-plugin-kubernetes_metadata_filter/issues/175