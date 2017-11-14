# ae-customization-samples
The below listed steps are for Creating a cluster with customization in JSON format


1)Need to down load the script from the below given git location and place it in your object store.(<absolute_script_path>)
https://github.com/Raviprasadpentakota/ae-customization-samples/blob/master/src/key-based-ssh.sh

2)Copy the public key of the machine from where we want to make passwordless ssh into a file and upload to the object store.(<absolute_path_public_key_file>)

3)Need to modify the given below  json template with the object store auth end point ,access key and secret access key.


cf create-service <service-name>  lite <Instance name>   -c <cluster parameters as json string or path to cluster parameters json file>


Template of cluster json

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
