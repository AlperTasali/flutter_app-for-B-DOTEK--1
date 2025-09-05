from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Optional
import uvicorn

app = FastAPI(title="Local Lookup API", version="1.2")

# İstek modeli
class LookupRequest(BaseModel):
    identifier_type: str  # "imei" veya "ip"
    identifier: str
    read_form: Optional[str] = None   # "readout", "lp", "obis"
    serial_no: Optional[str] = None
    port: Optional[str] = None
    options: Optional[str] = None
    lp_start: Optional[str] = None
    lp_end: Optional[str] = None
    obis_list: Optional[str] = None

# Demo database
modem_datas = [
    {
        "comm": {"CGMR": "/dev/ttyGSM3", "IMEI": "869518074768079", "IMSI": "286016567036494"},
        "information": {
            "cpu_temp": "55.083C",
            "imei": "869518074768079",
            "ipAddress": "10.176.173.63",
            "signalLevel": 24,
            "usage_flash": "48%",
            "usage_ram": 21728,
            "version": "IKOM-10U.61-101-115"
        },
        "io": {
            "AC": [
                {"date": "2025-05-24 20:22:44", "state": "AC_OK"},
                {"date": "2025-05-24 20:22:55", "state": "AC_FAIL"}
            ],
            "Reboot": [
                {"date": "2025-04-22 19:53:17", "state": "Kill"},
                {"date": "2025-07-01 12:22:45", "state": "PowerOn"}
            ]
        },
        "read_rate": [
            {"lp_rate": 100, "meter": "67554528", "readout_rate": 100, "taosos_rate": 0}
        ],
        "recieve_time": "2025-08-10 23:50:26",
        "relay_input_data": {
            "RELAY1": {"state": "0", "date": "2025-08-25 18:56:18"},
            "INPUT1": {"state": "1", "date": "2025-08-16 02:25:29"},
            "TEMP": {"state": "31", "date": "2025-08-25 12:29:10"}
        },
        "system_info": {
            "HW Version": "TIP_4_4G_ETH_E_SIM-3.4105",
            "SW Version": "IKOM-8U.62-106-119",
            "IMEI": "864011066782501",
            "Ethernet IP": {"ip": "192.169.10.176", "gateway": "192.169.10.1"}
        }
    },
    {
        "comm": {"CGMR": "/dev/ttyGSM4", "IMEI": "359876543210123", "IMSI": "286012345678901"},
        "information": {
            "cpu_temp": "48.250C",
            "imei": "359876543210123",
            "ipAddress": "10.176.174.10",
            "signalLevel": 30,
            "usage_flash": "52%",
            "usage_ram": 19500,
            "version": "IKOM-10U.61-101-120"
        },
        "io": {
            "AC": [
                {"date": "2025-06-01 15:30:00", "state": "AC_OK"},
                {"date": "2025-06-02 08:20:00", "state": "AC_FAIL"}
            ],
            "Reboot": [
                {"date": "2025-06-05 09:00:00", "state": "PowerOn"}
            ]
        },
        "read_rate": [
            {"lp_rate": 98, "meter": "67554529", "readout_rate": 96, "taosos_rate": 2}
        ],
        "recieve_time": "2025-08-15 14:30:45",
        "relay_input_data": {
            "RELAY2": {"state": "1", "date": "2025-08-20 10:15:00"},
            "INPUT2": {"state": "0", "date": "2025-08-21 11:20:00"},
            "TEMP": {"state": "28", "date": "2025-08-21 11:20:00"}
        },
        "system_info": {
            "HW Version": "TIP_4_4G_ETH_E_SIM-3.4200",
            "SW Version": "IKOM-8U.62-106-120",
            "IMEI": "359876543210123",
            "Ethernet IP": {"ip": "192.169.11.10", "gateway": "192.169.11.1"}
        }
    },
    {
        "comm": {"CGMR": "/dev/ttyGSM5", "IMEI": "490154203237518", "IMSI": "286019876543210"},
        "information": {
            "cpu_temp": "60.500C",
            "imei": "490154203237518",
            "ipAddress": "10.176.175.55",
            "signalLevel": 18,
            "usage_flash": "62%",
            "usage_ram": 25000,
            "version": "IKOM-10U.61-101-130"
        },
        "io": {
            "AC": [
                {"date": "2025-07-20 12:00:00", "state": "AC_FAIL"},
                {"date": "2025-07-20 12:05:00", "state": "AC_OK"}
            ],
            "Reboot": [
                {"date": "2025-07-21 09:30:00", "state": "Linux"}
            ]
        },
        "read_rate": [
            {"lp_rate": 95, "meter": "67554530", "readout_rate": 93, "taosos_rate": 5}
        ],
        "recieve_time": "2025-08-18 19:10:10",
        "relay_input_data": {
            "RELAY3": {"state": "0", "date": "2025-08-22 09:45:00"},
            "INPUT3": {"state": "1", "date": "2025-08-22 09:46:00"},
            "TEMP": {"state": "33", "date": "2025-08-22 09:46:00"}
        },
        "system_info": {
            "HW Version": "TIP_4_4G_ETH_E_SIM-3.4300",
            "SW Version": "IKOM-8U.62-106-130",
            "IMEI": "490154203237518",
            "Ethernet IP": {"ip": "192.169.12.55", "gateway": "192.169.12.1"}
        }
    }
]

@app.post("/lookup")
def lookup(data: LookupRequest):
    """
    IMEI veya IP ile cihaz araması yapar + seçilen okuma tipine göre özel veri döndürür
    """
    device = None
    for modem in modem_datas:
        if data.identifier_type.lower() == "imei" and modem["information"]["imei"] == data.identifier:
            device = modem
        if data.identifier_type.lower() == "ip" and modem["information"]["ipAddress"] == data.identifier:
            device = modem

    if not device:
        return {"ok": False, "message": "Modem bulunamadı."}

    # Eğer sadece cihaz bilgisi istenirse
    if not data.read_form:
        return {"ok": True, "data": device}

    # Okuma tipine göre ek bilgi döndür
    if data.read_form == "readout":
        return {
            "ok": True,
            "data": {
                "meter": data.serial_no or "67554528",
                "port": data.port,
                "options": data.options,
                "readout_rate": 100,
                "taosos_rate": 0
            }
        }

    if data.read_form == "lp":
        return {
            "ok": True,
            "data": {
                "meter": data.serial_no or "67554528",
                "port": data.port,
                "lp_start": data.lp_start,
                "lp_end": data.lp_end,
                "records": [
                    {"date": "2025-08-10 00:00:00", "value": 123.4},
                    {"date": "2025-08-10 01:00:00", "value": 127.8}
                ]
            }
        }

    if data.read_form == "obis":
        return {
            "ok": True,
            "data": {
                "meter": data.serial_no or "67554528",
                "port": data.port,
                "obis_list": data.obis_list,
                "results": {
                    "1.8.0": "230.5 kWh",
                    "32.7.0": "229.1 V"
                }
            }
        }

    return {"ok": False, "message": f"Bilinmeyen okuma tipi: {data.read_form}"}


@app.get("/")
def read_root():
    return {
        "message": "POST ile /lookup endpoint'ini kullanın.",
        "example": {
            "identifier_type": "imei",
            "identifier": "869518074768079",
            "read_form": "readout",
            "serial_no": "67554528",
            "port": "mxc1",
            "options": "0,6,7,8,9"
        }
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8040)
