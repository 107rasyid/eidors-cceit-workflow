$begin 'Profile'
	$begin 'ProfileGroup'
		MajorVer=2025
		MinorVer=2
		Name='Solution Process'
		$begin 'StartInfo'
			I(1, 'Start Time', '11/16/2026 21:28:26')
			I(1, 'Host', 'RASYID')
			I(1, 'Processor', '12')
			I(1, 'OS', 'NT 10.0')
			I(1, 'Product', 'Maxwell2D 2025.2.4')
		$end 'StartInfo'
		$begin 'TotalInfo'
			I(1, 'Elapsed Time', '00:00:02')
			I(1, 'ComEngine Memory', '74.6 M')
		$end 'TotalInfo'
		GroupOptions=8
		TaskDataOptions(Memory=8)
		ProfileItem('', 0, 0, 0, 0, 0, 'I(1, 1, \'Executing From\', \'C:\\\\Program Files\\\\ANSYS Inc\\\\ANSYS Student\\\\v252\\\\AnsysEM\\\\MAXWELL2DCOMENGINE.exe\')', false, true)
		$begin 'ProfileGroup'
			MajorVer=2025
			MinorVer=2
			Name='HPC'
			$begin 'StartInfo'
				I(1, 'Type', 'Manual')
				I(1, 'Distribution Types', 'Variations, Frequencies')
				I(1, 'MPI Vendor', 'Intel')
				I(1, 'MPI Version', '2021')
			$end 'StartInfo'
			$begin 'TotalInfo'
				I(0, ' ')
			$end 'TotalInfo'
			GroupOptions=0
			TaskDataOptions(Memory=8)
			ProfileItem('Machine', 0, 0, 0, 0, 0, 'I(4, 1, \'Name\', \'rasyid\', 3, \'RAM Limit\', 90, \'%f%%\', 2, \'Tasks\', 1, false, 2, \'Cores\', 4, false)', false, true)
		$end 'ProfileGroup'
		ProfileItem('Design Validation', 0, 0, 0, 0, 0, 'I(3, 1, \'Level\', \'Perform full validations\', 1, \'Elapsed Time\', \'00:00:00\', 2, \'Memory\', 74604, true)', false, true)
		$begin 'ProfileGroup'
			MajorVer=2025
			MinorVer=2
			Name='Initial Meshing'
			$begin 'StartInfo'
				I(1, 'Time', '11/16/2026 21:28:27')
			$end 'StartInfo'
			$begin 'TotalInfo'
				I(1, 'Elapsed Time', '00:00:01')
			$end 'TotalInfo'
			GroupOptions=4
			TaskDataOptions(Memory=8)
			ProfileItem('Mesh', 0, 0, 0, 0, 45000, 'I(2, 1, \'Type\', \'TAU(2D)\', 2, \'Triangles\', 1032, false)', true, true)
			ProfileItem('  Manual Refine', 0, 0, 0, 0, 173792, 'I(2, 2, \'Triangles\', 1926, false, 0, \'L_Medium, L_Thin\')', true, true)
		$end 'ProfileGroup'
		$begin 'ProfileGroup'
			MajorVer=2025
			MinorVer=2
			Name='Adaptive Meshing'
			$begin 'StartInfo'
				I(1, 'Time', '11/16/2026 21:28:28')
			$end 'StartInfo'
			$begin 'TotalInfo'
				I(1, 'Elapsed Time', '00:00:00')
			$end 'TotalInfo'
			GroupOptions=4
			TaskDataOptions(Memory=8)
			$begin 'ProfileGroup'
				MajorVer=2025
				MinorVer=2
				Name='Pass 1'
				$begin 'StartInfo'
				$end 'StartInfo'
				$begin 'TotalInfo'
					I(0, ' ')
				$end 'TotalInfo'
				GroupOptions=0
				TaskDataOptions(Memory=8)
				ProfileItem('  Matrix Solve', 0, 0, 0, 0, 2528, 'I(4, 1, \'Type\', \'DCS\', 2, \'Cores\', 4, false, 2, \'Matrix\', 3662, false, 1, \'Disk\', \'0KB\')', true, true)
				ProfileItem('  B6_YMatrix', 0, 0, 0, 0, 2507, 'I(4, 1, \'Type\', \'DCS\', 2, \'Cores\', 4, false, 2, \'Matrix\', 3662, false, 1, \'Disk\', \'0KB\')', true, true)
				ProfileItem('  Solve', 0, 0, 0, 0, 189340, 'I(1, 2, \'Triangles\', 1926, false)', true, true)
			$end 'ProfileGroup'
			ProfileFootnote('I(1, 0, \'Adaptive Passes converged\')', 0)
		$end 'ProfileGroup'
		ProfileFootnote('I(2, 1, \'Stop Time\', \'11/16/2026 21:28:29\', 1, \'Status\', \'Normal Completion\')', 0)
	$end 'ProfileGroup'
$end 'Profile'
