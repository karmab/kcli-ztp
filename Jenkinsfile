properties(
 [
  parameters (
    [
    booleanParam(name: 'wait', defaultValue: false, description: 'Wait for plan to finish'),
    string(name: 'kcli_client', defaultValue: "", description: 'Target Kcli client. Default one will be used if empty'),
    string(name: 'kcli_config_yml', defaultValue: "kcli-config-yml", description: 'Secret File Credential storing your ~/.kcli/config.yml'),
    string(name: 'kcli_id_rsa', defaultValue: "kcli-id-rsa", description: 'Secret File Credential storing your private key'),
    string(name: 'kcli_id_rsa_pub', defaultValue: "kcli-id-rsa-pub", description: 'Secret File Credential container your public key'),
    string(name: 'info', defaultValue: "This deploys a vm where:
- openshift-baremetal-install is downloaded or compiled)
- caches the rhcos images
- stop the nodes to deploy through ipmi
- launch the install against a set of baremetal nodes (and optionally virtual masters)
It can be used with a centos8 or rhel8 vm (in which case you will need to set your rhn credentials in your kcli config)
default location for your pull secret is openshift_pull.json but you can choose another with the pullsecret variable
You will need to define api_ip, dns_ip and ingress_ip and use the masters and workers array to specify your nodes.
Nfs can be set to true to create 10 rwx pvs and 10 rwo pvs on the provisioning vm
default network type is OVNKubernetes but you can also specify OpenShiftSDN
You can also use ca and imagecontentsources to customize your environments or drop specific manifests in the manifests directory
If using virtual masters, the masters array can be omitted.
For virtual masters, You can
- force the baremetal macs of your masters using baremetal_macs variable. If you put more entries than your masters number, they will be used for virtual workers.
- set a pattern for their provisioning macs when you plan to host several cluster with virtual masters on the same hypervisor
If build is set to true, the openshift install binary will be compiled from sources, optionally with the prs from prs variable array
", description: ''),
    string(name: 'image', defaultValue: "centos8", description: ''),
    string(name: 'installer_mac', defaultValue: "", description: ''),
    string(name: 'installer_wait', defaultValue: "False", description: ''),
    string(name: 'openshift_image', defaultValue: "registry.ci.openshift.org/ocp/release:4.7", description: ''),
    string(name: 'playbook', defaultValue: "False", description: ''),
    string(name: 'cluster', defaultValue: "openshift", description: ''),
    string(name: 'domain', defaultValue: "karmalabs.com", description: ''),
    string(name: 'network_type', defaultValue: "OVNKubernetes", description: ''),
    string(name: 'keys', defaultValue: "[]", description: ''),
    string(name: 'api_ip', defaultValue: "", description: ''),
    string(name: 'dns_ip', defaultValue: "", description: ''),
    string(name: 'ingress_ip', defaultValue: "", description: ''),
    string(name: 'image_url', defaultValue: "", description: ''),
    string(name: 'network', defaultValue: "default", description: ''),
    string(name: 'pool', defaultValue: "default", description: ''),
    string(name: 'numcpus', defaultValue: "16", description: ''),
    string(name: 'masters', defaultValue: "[]", description: ''),
    string(name: 'workers', defaultValue: "[]", description: ''),
    string(name: 'memory', defaultValue: "32768", description: ''),
    string(name: 'disk_size', defaultValue: "30", description: ''),
    string(name: 'extra_disks', defaultValue: "[]", description: ''),
    string(name: 'rhnregister', defaultValue: "True", description: ''),
    string(name: 'rhnwait', defaultValue: "30", description: ''),
    string(name: 'provisioning_enable', defaultValue: "True", description: ''),
    string(name: 'baremetal_noprovisioning_ip', defaultValue: "", description: ''),
    string(name: 'baremetal_noprovisioning_bootstrap_ip', defaultValue: "", description: ''),
    string(name: 'provisioning_interface', defaultValue: "eno1", description: ''),
    string(name: 'provisioning_net', defaultValue: "provisioning", description: ''),
    string(name: 'provisioning_ip', defaultValue: "172.22.0.3", description: ''),
    string(name: 'provisioning_cidr', defaultValue: "172.22.0.0/24", description: ''),
    string(name: 'provisioning_range', defaultValue: "172.22.0.10,172.22.0.100", description: ''),
    string(name: 'provisioning_installer_ip', defaultValue: "172.22.0.253", description: ''),
    string(name: 'provisioning_macs', defaultValue: "[]", description: ''),
    string(name: 'ipmi_user', defaultValue: "root", description: ''),
    string(name: 'ipmi_password', defaultValue: "calvin", description: ''),
    string(name: 'baremetal_net', defaultValue: "baremetal", description: ''),
    string(name: 'baremetal_cidr', defaultValue: "", description: ''),
    string(name: 'baremetal_macs', defaultValue: "[]", description: ''),
    string(name: 'baremetal_ips', defaultValue: "[]", description: ''),
    string(name: 'pullsecret', defaultValue: "openshift_pull.json", description: ''),
    string(name: 'notifyscript', defaultValue: "notify.sh", description: ''),
    string(name: 'virtual_protocol', defaultValue: "ipmi", description: ''),
    string(name: 'virtual_masters', defaultValue: "False", description: ''),
    string(name: 'virtual_masters_number', defaultValue: "3", description: ''),
    string(name: 'virtual_masters_numcpus', defaultValue: "8", description: ''),
    string(name: 'virtual_masters_memory', defaultValue: "32768", description: ''),
    string(name: 'virtual_masters_mac_prefix', defaultValue: "aa:aa:aa:aa:aa", description: ''),
    string(name: 'virtual_masters_baremetal_mac_prefix', defaultValue: "aa:aa:aa:cc:cc", description: ''),
    string(name: 'virtual_workers', defaultValue: "False", description: ''),
    string(name: 'virtual_workers_number', defaultValue: "1", description: ''),
    string(name: 'virtual_workers_numcpus', defaultValue: "8", description: ''),
    string(name: 'virtual_workers_memory', defaultValue: "16384", description: ''),
    string(name: 'virtual_workers_mac_prefix', defaultValue: "aa:aa:aa:bb:bb", description: ''),
    string(name: 'virtual_workers_baremetal_mac_prefix', defaultValue: "aa:aa:aa:dd:dd", description: ''),
    string(name: 'virtual_workers_deploy', defaultValue: "True", description: ''),
    string(name: 'cache', defaultValue: "True", description: ''),
    string(name: 'notify', defaultValue: "True", description: ''),
    string(name: 'launch_steps', defaultValue: "True", description: ''),
    string(name: 'deploy_openshift', defaultValue: "True", description: ''),
    string(name: 'lab', defaultValue: "False", description: ''),
    string(name: 'disconnected', defaultValue: "False", description: ''),
    string(name: 'registry_image', defaultValue: "quay.io/saledort/registry:2", description: ''),
    string(name: 'registry_user', defaultValue: "dummy", description: ''),
    string(name: 'registry_password', defaultValue: "dummy", description: ''),
    string(name: 'nfs', defaultValue: "True", description: ''),
    string(name: 'imageregistry', defaultValue: "False", description: ''),
    string(name: 'build', defaultValue: "False", description: ''),
    string(name: 'go_version', defaultValue: "1.13.8", description: ''),
    string(name: 'prs', defaultValue: "[]", description: ''),
    string(name: 'imagecontentsources', defaultValue: "[]", description: ''),
    string(name: 'fips', defaultValue: "False", description: ''),
    string(name: 'cas', defaultValue: "[]", description: ''),
    string(name: 'nbde', defaultValue: "False", description: ''),
    string(name: 'ntp', defaultValue: "False", description: ''),
    string(name: 'ntp_server', defaultValue: "0.rhel.pool.ntp.org", description: ''),
    string(name: 'model', defaultValue: "dell", description: ''),
    ]
  )
 ]
)

pipeline {
    agent any
    environment {
     KCLI_CONFIG = credentials("${params.kcli_config_yml}")
     KCLI_SSH_ID_RSA = credentials("${params.kcli_id_rsa}")
     KCLI_SSH_ID_RSA_PUB = credentials("${params.kcli_id_rsa_pub}")
     KCLI_PARAMETERS = "-P info=${params.info} -P image=${params.image} -P installer_mac=${params.installer_mac} -P installer_wait=${params.installer_wait} -P openshift_image=${params.openshift_image} -P playbook=${params.playbook} -P cluster=${params.cluster} -P domain=${params.domain} -P network_type=${params.network_type} -P keys=${params.keys} -P api_ip=${params.api_ip} -P dns_ip=${params.dns_ip} -P ingress_ip=${params.ingress_ip} -P image_url=${params.image_url} -P network=${params.network} -P pool=${params.pool} -P numcpus=${params.numcpus} -P masters=${params.masters} -P workers=${params.workers} -P memory=${params.memory} -P disk_size=${params.disk_size} -P extra_disks=${params.extra_disks} -P rhnregister=${params.rhnregister} -P rhnwait=${params.rhnwait} -P provisioning_enable=${params.provisioning_enable} -P baremetal_noprovisioning_ip=${params.baremetal_noprovisioning_ip} -P baremetal_noprovisioning_bootstrap_ip=${params.baremetal_noprovisioning_bootstrap_ip} -P provisioning_interface=${params.provisioning_interface} -P provisioning_net=${params.provisioning_net} -P provisioning_ip=${params.provisioning_ip} -P provisioning_cidr=${params.provisioning_cidr} -P provisioning_range=${params.provisioning_range} -P provisioning_installer_ip=${params.provisioning_installer_ip} -P provisioning_macs=${params.provisioning_macs} -P ipmi_user=${params.ipmi_user} -P ipmi_password=${params.ipmi_password} -P baremetal_net=${params.baremetal_net} -P baremetal_cidr=${params.baremetal_cidr} -P baremetal_macs=${params.baremetal_macs} -P baremetal_ips=${params.baremetal_ips} -P pullsecret=${params.pullsecret} -P notifyscript=${params.notifyscript} -P virtual_protocol=${params.virtual_protocol} -P virtual_masters=${params.virtual_masters} -P virtual_masters_number=${params.virtual_masters_number} -P virtual_masters_numcpus=${params.virtual_masters_numcpus} -P virtual_masters_memory=${params.virtual_masters_memory} -P virtual_masters_mac_prefix=${params.virtual_masters_mac_prefix} -P virtual_masters_baremetal_mac_prefix=${params.virtual_masters_baremetal_mac_prefix} -P virtual_workers=${params.virtual_workers} -P virtual_workers_number=${params.virtual_workers_number} -P virtual_workers_numcpus=${params.virtual_workers_numcpus} -P virtual_workers_memory=${params.virtual_workers_memory} -P virtual_workers_mac_prefix=${params.virtual_workers_mac_prefix} -P virtual_workers_baremetal_mac_prefix=${params.virtual_workers_baremetal_mac_prefix} -P virtual_workers_deploy=${params.virtual_workers_deploy} -P cache=${params.cache} -P notify=${params.notify} -P launch_steps=${params.launch_steps} -P deploy_openshift=${params.deploy_openshift} -P lab=${params.lab} -P disconnected=${params.disconnected} -P registry_image=${params.registry_image} -P registry_user=${params.registry_user} -P registry_password=${params.registry_password} -P nfs=${params.nfs} -P imageregistry=${params.imageregistry} -P build=${params.build} -P go_version=${params.go_version} -P prs=${params.prs} -P imagecontentsources=${params.imagecontentsources} -P fips=${params.fips} -P cas=${params.cas} -P nbde=${params.nbde} -P ntp=${params.ntp} -P ntp_server=${params.ntp_server} -P model=${params.model}"
     CONTAINER_OPTIONS = "--net host --rm --security-opt label=disable -v $HOME/.kcli:/root/.kcli -v $PWD:/workdir -v /var/tmp:/ignitiondir"
     KCLI_CMD = "podman run ${CONTAINER_OPTIONS} karmab/kcli"
    }
    stages {
        stage('Prepare kcli environment') {
            steps {
                sh '''
                [ -d $HOME/.kcli ] && rm -rf $HOME/.kcli
                mkdir $HOME/.kcli
                cp "$KCLI_CONFIG" $HOME/.kcli/config.yml
                cp "$KCLI_SSH_ID_RSA" $HOME/.kcli/id_rsa
                chmod 600 $HOME/.kcli/id_rsa
                cp "$KCLI_SSH_ID_RSA_PUB" $HOME/.kcli/id_rsa.pub
                '''
            }
        }
        stage('Check kcli client') {
            steps {
                sh '${KCLI_CMD} list client'
            }
        }
        stage('Deploy kcli plan') {
            steps {
                script {
                  KCLI_CLIENT = ""
                  if ( "${params.kcli_client}" != "" ) {
                     KCLI_CLIENT = "-C ${params.kcli_client}"
                  }
                  if ( "${params.wait}" == "true" ) {
                     WAIT = "--wait"
                  } else {
                     WAIT = ""
                  }
                }
                sh """
                  ${KCLI_CMD} ${KCLI_CLIENT} create plan -f ${WORKSPACE}/kcli_plan.yml ${KCLI_PARAMETERS} ${WAIT} ${env.JOB_NAME}_${env.BUILD_NUMBER}
                """
            }
        }
    }
}
