define mysql-restore::sqlfile (
	$filename = '',  
	$filepath='',
	$remotehost = '',
	$workdir ='',
	$sourcehost = '',
	$sshuser = '',
	$sshport = '22',
	$restoreuser = '',
	$restorepasswd = '',
	$compressed = '',
) {
#If no filename definied we assume that the resource name is the one
	if $filename == '' {
		$fname = $name
	} else {
		$fname = $filename
	}

#If no work directory specified we use /tmp
	if $workdir == '' {
		$lpath = '/tmp'	
	} else {
		$lpath = $workdir
	}
#Set command to read the backup file
	case $compressed {
		'gzip': {
			$command = 'gzip -d'
		}
		'bzip': {
			$command = 'bzcat'
		}
		default : {
			$command = "cat"
		}
	}

#If backup file on diffrent host we copy it over to the work directory unless content hash is the same as in the pervious run.
	if $sourcehost != '' {
		exec {"copy_backup_file_from_${orighost}_${fname}":
			path => ['/bin','/sbin','/usr/bin','usr/sbin'],
			command => "scp -P $sshport $sshuser@${sourcehost}:${filepath}/${fname} ${lpath}/${fname}",
			unless => "ssh -p $sshport -l $sshuser -o StrictHostKeyChecking=no -o UserknownHostsFile=/dev/null $sourcehost \"head -c 1024k ${filepath}/${fname}\" | sha256sum | grep `cat ${lpath}/${fname}.hash`",
			notify => Exec["restore_file_${lpath}_${fname}"],
		}
	} else {
#If backup file local copy to the work directory unless content hash is the same as before
		exec {"copy_backup_file_${fname}_to_workdir":
			path => ['/bin','/sbin','/usr/bin','usr/sbin'],
			command => "cp ${filepath}/${fname} ${lpath}/${fname}",
			unless => "head -c 1024k ${filepath}/${fname} | sha256sum | grep `cat ${lpath}/${fname}.hash`",
			notify => Exec["restore_file_${lpath}_${fname}"],
		}
	}
	

#Create hash of file
	exec {"create_hash_of_file_${fname}":
		path => ['/bin','/sbin','/usr/bin','usr/sbin'],
		command => "head -c 1024k ${lpath}/${fname} | sha256sum > ${lpath}/${fname}.hash",
		refreshonly => 'true',
		notify => Exec["delete_file_${lpath}/${fname}"]
	}

#Restore file to mysql server
	exec {"restore_file_${lpath}_${fname}":
		path => ['/bin','/sbin','/usr/bin','usr/sbin'],
		command => "$command ${lpath}/${fname} |  mysql -u ${restoreuser} -p${restorepasswd}",
		refreshonly => 'true',
		notify => Exec["create_hash_of_file_${fname}"]
	}

#Delete file from workdir after restore
	exec {"delete_file_${lpath}/${fname}":
		path =>  ['/bin','/sbin','/usr/bin','usr/sbin'],
		command => "rm -r ${lpath}/${fname}",
		refreshonly => 'true',
	}

	if $mysql_integrity == 'fals' {
		warning("$hostname Mysql Database server integrity compromised")
	}
}
