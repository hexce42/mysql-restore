Facter.add ("mysql_integrity") do
	setcode do
		errors = Facter::Util::Resolution.exec('echo "select concat(\"check table \",table_schema,\".\",table_name,\";\") from information_schema.tables" | mysql -N| mysql -N | grep error')
		if errors.length == 0
			true
		else 
			false
		end
	end
end
