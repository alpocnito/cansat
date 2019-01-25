import json
def convert(msb, lsb):
    z = 1
    g = (msb << 8) | lsb
    if g >> 15 > 0:
        z = 0
        g = 65536 - g + 1
    
    x = 0
    msb = g >> 8
    lsb = g % 256
    msb %= 16
    dev = 8
    while msb > 0:
        x += (msb // dev) * dev
        msb %= dev
        dev //= 2
    dev = 128
    while lsb > 0:
        x += (lsb // dev) * (dev / (2**8))
        lsb %= dev
        dev //= 2
    if z:
        return x
    else:
        return -x


dig_T1 = 28334.0
dig_T2 = 26234.0
dig_T3 = 50.0
dig_P1 = 36393
dig_P2 = -10592 
dig_P3 = 3024
dig_P4 = 4117
dig_P5 = 229
dig_P6 = -7
dig_P7 = 15500
dig_P8 = -14600
dig_P9 = 6000

def ret_fine(adc_T):
    var1 = ((adc_T / 16384.0) - (dig_T1 / 1024.0)) * dig_T2
    var2 = ((adc_T / 131072.0) - (dig_T1 / 8192.0)) * dig_T3
    t_fine = int(var1 + var2)
    return t_fine
def tempa(adc_T):
    var1 = ((adc_T / 16384.0) - (dig_T1 / 1024.0)) * dig_T2
    var2 = ((adc_T / 131072.0) - (dig_T1 / 8192.0)) * dig_T3
    T = (var1 + var2) / 5120.0
    return T
def press(adc_P, adc_T):
    var1 = ret_fine(adc_T) - 128000
    var2 = var1 * var1 * dig_P6
    var2 = var2 + ((var1 * dig_P5) << 17)
    var2 = var2 + (dig_P4 << 35)
    var1 = ((var1 * var1 * dig_P3) >> 8) + ((var1 * dig_P2) << 12)
    var1 = ((((1 << 47) + var1)) * dig_P1) >> 33
    if (var1 == 0):
        print("BMP280_compensate_P_Int64 Jump out to avoid / 0")
        return 0
    p = 1048576 - adc_P
    p = int((((p << 31) - var2) * 3125) / var1)
    var1 = (dig_P9 * (p >> 13) * (p >> 13)) >> 25
    var2 = (dig_P8 * p) >> 19
    p = ((p + var1 + var2) >> 8) + (dig_P7 << 4)
    return p / 256

import serial
ser = serial.Serial(
    port='COM9',\
    baudrate=115200,\
    parity=serial.PARITY_NONE,\
    stopbits=serial.STOPBITS_ONE,\
    bytesize=serial.EIGHTBITS,\
        timeout=0)
l = []
for i in range(1000000000):
    a = ser.read()
    if a != b'':
        if int.from_bytes(a, byteorder='big') == 51:
            if len(l) >= 12:
                x = convert(l[1], l[0]) + 0.03
                y = convert(l[3], l[2]) + 0.03
                z = convert(l[5], l[4]) - 0.03
                g = (x ** 2 + y ** 2 + z ** 2) ** 0.5
                
                adc_P = int(l[6] * 4096 + l[7] * 16 + l[8]/ 16)
                adc_T = int(l[9] * 4096 + l[10] * 16 + l[11]/ 16)
                temp_v = tempa(adc_T)
                press_v = press(adc_P, adc_T)
                #print(g, temp_v, press_v, ((101325 / press_v)**(1/5.257) - 1) * (temp_v + 273.15) / 0.0065)
                with open("data_file.json", "w") as write_file:
                    json.dump([g, temp_v, press_v, ((101325 / press_v)**(1/5.257) - 1) * (temp_v + 273.15) / 0.0065], write_file)
            l = []
        else:
            l.append(int.from_bytes(a, byteorder='big'))
            #print(a, int.from_bytes(a, byteorder='big'))
ser.close()
