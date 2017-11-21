# key-based-ssh-customization-script
Enable key based ssh authentication using the `key-based-ssh.sh` customization script. This script expects the public ssh key to stored into COS-S3 object store. Steps to consume this script:

- Download the script from the below given git location and place it in your COS-S3 object store. Make a note of absolute path of the script including the bucket name- <absolute_script_path>. 
	- https://github.com/Raviprasadpentakota/ae-customization-samples/blob/master/src/key-based-ssh.sh

- Upload the public ssh key you want to apply to the cluster into COS-S3 object store. Make a note of absolute path of the key file including the bucket name- <absolute_path_public_key_file>

- Update the following cluster creation template to point to the customization script, public ssh key, COS-S3 authentication end-point and your COS-S3 authentication details(auth_key and secret_access_key) 

#### Template of create cluster with key based ssh authentication.
```
{
	"num_compute_nodes": 1,
	"hardware_config": "default",
	"software_package": "ae-1.0-spark",
	"customization": [{
		"name": "action1COSS3",
		"type": "bootstrap",
		"script": {
			"source_type": "CosS3",
			"source_props": {
				"auth_endpoint": "<cos_object_store_auth_end_point>",
				"access_key_id": "<access_key_id>",
				"secret_access_key": "<secret_access_key>"
			},
			"script_path": "<absolute_script_path>"
		},
		"script_params": ["https://<cos_object_store_auth_end_point>", "<secret_access_key>", "<access_key_id>", "<absolute_path_public_key_file>"]
	}]
}
```

- Use the below mentioned cf command and json prepared in previous step to create cluster with key based ssh authenticaiton. 
```
cf create-service <service-name>  lite <Instance name>   -c <cluster parameters as json string or path to cluster parameters json file>
```

