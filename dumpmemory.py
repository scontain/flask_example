import sys,re

pid = sys.argv[1]
print("PID = %s \n" % pid)
maps_file = open("/proc/%s/maps" % pid, 'r')
mem_file= open("/proc/%s/mem" % pid, 'rb')

for line in maps_file.readlines():
    m = re.match(r'([0-9A-Fa-f]+)-([0-9A-Fa-f]+) ([-r][-w])', line)
    if m.group(3) == "rw" or m.group(3) == "r-" :
        try:
            start = int(m.group(1), 16)
            if start > 0xFFFFFFFFFFFF:
                continue
            print("\nOK : \n" + line+"\n")
            end = int(m.group(2), 16)
            mem_file.seek(start) 
            chunk = mem_file.read(end - start)
            print(chunk)
            sys.stdout.flush()
        except Exception as e:
            print(str(e))  
    else:
        print("\nPASS : \n" + line+"\n")

print("END")
