{
  _config+:: {

    zookeeper+: {
      name: 'zookeeper',
      namespace: $._config.namespace,

      cluster_domain: 'cluster.local',

      pvc_class: 'standard',
      data_pvc_size: '2Gi',
      log_pvc_size: '2Gi',

      service_name: self.name,
      service_name_headless: '%(name)s-headless' % self,
      sa_name: self.name,
      sts_name: self.name,
      cm_name: self.name,
      labels: {
        app: 'zookeeper',
      },
      standalone: false,  // this one is fixed for now, only clustered mode supported
      node_count: if self.standalone then 1 else 3,  // Cluster
      prometheus: {
        port: 7000,
        scrape: true,
      },
    },
  },

  _images+:: {
    zookeeper: 'zookeeper:3.7.0',
  },

}
