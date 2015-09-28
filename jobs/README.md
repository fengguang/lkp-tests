# Job definition to execution


Job files are the basic unit of test description and execution.
They are written in [YAML](http://yaml.org/YAML_for_ruby.html) format.

In the most fundemental form, a job YAML contains a hash table of key-values.
The keys fall into 2 main categories:

## Scripts

If the key matches some script file in the below paths, it is treated as an
executable script.

  - $LKP_SRC/setup
  - $LKP_SRC/monitors
  - $LKP_SRC/daemon
  - $LKP_SRC/tests


## Variables

Otherwise if

  - the key is a valid keyword
  - the value is a string or an array of strings

They will be exported as environment variables.

`$LKP_SRC/sbin/job2sh` uses the above 2 main rules to convert a job YAML file
into an executable shell script. Here is a conceptual demo.

```
	job.yaml (by USER)             ===>     job.sh (by LKP)
	define environment & actions            compile into sh for execution
	~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	  testcase: ...                            export  testcase=...
	  testbox: ...                             export  testbox=...
	  kconfig: ...                             export  kconfig=...
	  commit: ...                              export  commit=...
	  rootfs: ...                              export  rootfs=...
	  test_param1: ...                         export  test_param1=...
	  test_param2: ...                         export  test_param2=...
	  ...                                      ...
	  setup_script1:                           $LKP_SRC/setup/setup_script1
	  setup_script2:                           $LKP_SRC/setup/setup_script2
	  test_script:                             $LKP_SRC/tests/test_script
```
## job allocation
This page (README-job-allocation.html) talks about job allocation
