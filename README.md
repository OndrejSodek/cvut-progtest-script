# cvut-progtest-script
Checks your program against reference data from Progtest (@ CVUT FIT)

## Description
Automatically looks for test data, extracts those from an archive if needed.  
Automatically compiles your program if needed.

If program output differs from the reference, will print a few lines of differences.

Should only write data to disk when compiling or extracting data from archive.  
Shouldn't ovewrite anything other than compiled binary file.

## Usage
```
progtest.sh path/to/source-file.c [path/to/test/data/]
```

### Examples
```
../progtest.sh progtest1.c sample.tgz
../progtest.sh progtest1.c sample/
../progtest.sh progtest1
```

These 3 examples do the same thing

(You may want to put progtest.sh somewhere in your $PATH)

## Dependencies
* required
	* bash
	* g++/gcc
* optional
	* tar

## License
This project is licensed under the terms of the MIT license.
