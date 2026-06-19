from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel


class ComponentCreate(BaseModel):
    component_no: str
    model_id: int
    batch_no: Optional[str] = None
    production_date: Optional[date] = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "component_no": "ENG-009",
                "model_id": 1,
                "batch_no": "BATCH-2025-01",
                "production_date": "2025-01-01",
            }
        }
    }


class InstallationCreate(BaseModel):
    component_no: str
    aircraft_no: str
    install_position: str
    install_time: datetime
    install_reason: Optional[str] = None
    operator_id: Optional[int] = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "component_no": "ENG-003",
                "aircraft_no": "AC-1002",
                "install_position": "right engine position",
                "install_time": "2025-06-01 09:00:00",
                "install_reason": "normal installation",
                "operator_id": 1,
            }
        }
    }


class InstallationUninstall(BaseModel):
    uninstall_time: datetime
    uninstall_reason: Optional[str] = None
    uninstall_operator_id: Optional[int] = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "uninstall_time": "2025-06-01 12:00:00",
                "uninstall_reason": "regular inspection",
                "uninstall_operator_id": 1,
            }
        }
    }


class ComponentReplace(BaseModel):
    old_component_no: str
    new_component_no: str
    aircraft_no: str
    install_position: str
    replace_time: datetime
    operator_id: int
    uninstall_reason: Optional[str] = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "old_component_no": "ENG-001",
                "new_component_no": "ENG-002",
                "aircraft_no": "AC-1001",
                "install_position": "left engine position",
                "replace_time": "2025-06-01 09:00:00",
                "operator_id": 1,
                "uninstall_reason": "replacement test",
            }
        }
    }


class MaintenanceCreate(BaseModel):
    component_no: str
    maintenance_type: str
    start_time: datetime
    description: Optional[str] = None
    technician_id: Optional[int] = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "component_no": "HYD-001",
                "maintenance_type": "regular inspection",
                "start_time": "2025-06-02 09:00:00",
                "description": "start inspection",
                "technician_id": 2,
            }
        }
    }


class MaintenanceComplete(BaseModel):
    end_time: datetime
    result: Literal["passed", "failed", "scrapped"]
    description: Optional[str] = None
    approved_by: Optional[int] = None
    retirement_reason: Optional[str] = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "end_time": "2025-06-03 10:00:00",
                "result": "passed",
                "description": "maintenance passed",
                "approved_by": None,
                "retirement_reason": None,
            }
        }
    }


class ComponentRetire(BaseModel):
    retirement_time: datetime
    retirement_reason: str
    approved_by: int
    remark: Optional[str] = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "retirement_time": "2025-06-05 10:00:00",
                "retirement_reason": "life limit reached",
                "approved_by": 3,
                "remark": "approved by maintenance department",
            }
        }
    }


class FlightCreate(BaseModel):
    aircraft_no: str
    mission_no: str
    takeoff_time: datetime
    landing_time: datetime
    mission_type: Optional[str] = None
    recorded_by: Optional[int] = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "aircraft_no": "AC-1001",
                "mission_no": "M-2025-001",
                "takeoff_time": "2025-05-01 08:00:00",
                "landing_time": "2025-05-01 10:30:00",
                "mission_type": "training",
                "recorded_by": 4,
            }
        }
    }
