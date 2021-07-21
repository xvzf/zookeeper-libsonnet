local kausal = (import 'ksonnet-util/kausal.libsonnet');

(import 'config.libsonnet')
+ {

  local this = self,
  local k = kausal { _config+:: this._config },

  local container = k.core.v1.container,
  local volumeMount = k.core.v1.volumeMount,
  local statefulSet = k.apps.v1.statefulSet,
  local service = k.core.v1.service,
  local pvc = k.core.v1.persistentVolumeClaim,
  local pdb = k.policy.v1beta1.podDisruptionBudget,

  local config = $._config.zookeeper,
  local images = $._images,

    k8s_sa:
      $.core.v1.serviceAccount.new(config.sa_name)
      + $.core.v1.serviceAccount.metadata.withLabelsMixin(config.labels),

    data_pvc::
      pvc.new('zookeeper-data')
      + pvc.spec.resources.withRequestsMixin({ storage: config.data_pvc_size })
      + pvc.spec.withAccessModesMixin(['ReadWriteOnce'])
      + pvc.spec.withStorageClassName(config.pvc_class),

    log_pvc::
      pvc.new('zookeeper-log')
      + pvc.spec.resources.withRequestsMixin({ storage: config.log_pvc_size })
      + pvc.spec.withAccessModesMixin(['ReadWriteOnce'])
      + pvc.spec.withStorageClassName(config.pvc_class),

    cm:
      $.core.v1.configMap.new(config.cm_name)
      + $.core.v1.configMap.withDataMixin({
        local node_dns = {
          node_0: '%(sts_name)s-0.%(service_name_headless)s.%(namespace)s.svc.%(cluster_domain)s' % config,
          node_1: '%(sts_name)s-1.%(service_name_headless)s.%(namespace)s.svc.%(cluster_domain)s' % config,
          node_2: '%(sts_name)s-2.%(service_name_headless)s.%(namespace)s.svc.%(cluster_domain)s' % config,
        },

        // Generate configuration for every node
        ['%(sts_name)s-0.cfg' % config]: (importstr './config/zookeeper.cfg') % node_dns { node_0: '0.0.0.0' },
        ['%(sts_name)s-1.cfg' % config]: (importstr './config/zookeeper.cfg') % node_dns { node_1: '0.0.0.0' },
        ['%(sts_name)s-2.cfg' % config]: (importstr './config/zookeeper.cfg') % node_dns { node_2: '0.0.0.0' },
      }),

    pdb:
      pdb.new(config.name)
      + pdb.spec.selector.withMatchLabels(config.labels)
      + pdb.spec.withMaxUnavailable(1)
,

    zookeeper_container::
      container.new('zookeeper', images.zookeeper)
      + container.withCommand(['/bin/bash'])
      + container.withArgs(['-c', (importstr './config/zookeeper_startup.sh') % config])
      + container.withPorts([
        $.core.v1.containerPort.new('tcp-client', 2181),
        $.core.v1.containerPort.new('tcp-server', 2888),
        $.core.v1.containerPort.new('tcp-election', 3888),
      ])
      + container.withVolumeMountsMixin([
        volumeMount.new('zookeeper-data', '/data'),
        volumeMount.new('zookeeper-log', '/datalog'),
        volumeMount.new('zookeeper-k8s-config', '/k8s-config'),
      ])
      + container.withEnvMixin([
        $.core.v1.envVar.fromFieldPath('NODE_NAME', 'metadata.name'),
      ])
      // FIXME revisit after performance evaluation
      + $.util.resourcesRequests('500m', '512Mi')
      + $.util.resourcesLimits('1000m', '768Mi'),

    sts:
      statefulSet.new(
        name=config.sts_name,
        replicas=config.node_count,
        containers=[self.zookeeper_container],
        podLabels=config.labels,
      )
      + statefulSet.spec.template.spec.withServiceAccountName(self.k8s_sa.metadata.name)
      + statefulSet.metadata.withLabelsMixin(config.labels)
      // FIXME enable istio mTLS for the datastore
      + statefulSet.spec.template.metadata.withAnnotations({ 'sidecar.istio.io/inject': 'false' })
      + statefulSet.spec.withServiceName(config.service_name_headless)
      + statefulSet.spec.template.spec.withVolumesMixin([
        $.core.v1.volume.fromConfigMap('zookeeper-k8s-config', configMapName=config.cm_name),
      ])
      + statefulSet.spec.withVolumeClaimTemplatesMixin([
        self.data_pvc,
        self.log_pvc,
      ])
      + $.util.antiAffinityStatefulSet,

    svc_headless:
      $.util.serviceFor(self.sts, nameFormat='%(port)s')
      + service.metadata.withName(config.service_name_headless)
      + service.spec.withPublishNotReadyAddresses(true)
      + service.spec.withClusterIP('None')
      + { spec+: { ports:: [] } },

    svc_client:
      $.util.serviceFor(self.sts)
      + service.metadata.withName(config.service_name)
      + service.spec.withPorts([
        { name: 'tcp-client', port: 2181 },
      ]),

}
