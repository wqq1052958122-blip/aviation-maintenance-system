SUCCESS_RESPONSE = {
    200: {
        "description": "请求成功。所有接口统一返回 success 和 data。",
        "content": {
            "application/json": {
                "example": {
                    "success": True,
                    "data": {}
                }
            }
        },
    },
    400: {
        "description": "请求失败。前端可直接展示 message 字段。",
        "content": {
            "application/json": {
                "example": {
                    "success": False,
                    "message": "Retired component cannot be installed."
                }
            }
        },
    },
}

OPENAPI_TAGS = [
    {"name": "health", "description": "服务健康检查。先测试这个接口确认后端已启动。"},
    {"name": "basic", "description": "基础数据查询，包括飞机、操作人员、当前安装状态。"},
    {"name": "component-models", "description": "部件型号查询，新部件入库时需要使用 model_id。"},
    {"name": "components", "description": "部件入库、档案、生命周期、飞行统计、更换和退役。"},
    {"name": "installations", "description": "部件安装和拆卸。数据库触发器负责拦截非法安装。"},
    {"name": "maintenances", "description": "维修记录创建、维修完成和部件维修历史查询。"},
    {"name": "flights", "description": "飞行日志创建与查询。flight_hours 由后端自动计算。"},
    {"name": "stats", "description": "统计分析接口，主要读取数据库视图。"},
]
