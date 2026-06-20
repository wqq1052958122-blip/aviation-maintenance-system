const normalize = (value) => String(value ?? '').trim().toLowerCase()

const maintenanceTypeMap = {
  'online inspection': '在线检查',
  'routine inspection': '例行检查',
  'regular inspection': '例行检查',
  'scheduled inspection': '计划检查',
  'scheduled maintenance': '计划维修',
  routine: '常规检查',
  repair: '维修',
  'fault repair': '故障维修',
  overhaul: '深度大修',
  'replacement check': '更换检查',
  post_removal_inspection: '拆卸后检查',
  'life warning inspection': '寿命预警检查',
  'status lock test': '状态锁定测试',
  'cancel lock test': '取消锁定测试'
}

const retirementReasonMap = {
  'life limit reached': '达到寿命限制',
  'life limit reached after replacement': '更换后达到寿命限制',
  'irreparable damage found during inspection': '检查发现不可修复损伤',
  'scrapped after maintenance': '维修后报废',
  'manual retirement': '人工退役',
  other: '其他原因',
  'n/a': '未填写原因'
}

const commonTextMap = {
  'initial installation': '初始安装',
  'reinstallation after maintenance': '维修后重新安装',
  'performance check': '性能检查',
  'component replacement': '部件更换',
  'normal installation': '正常安装',
  'routine online inspection passed.': '例行在线检查通过。',
  'hydraulic pressure test passed.': '液压压力测试通过。',
  'navigation module under repair.': '导航模块正在维修。',
  'navigation module repaired and test passed.': '导航模块维修并测试通过。',
  'online inspection for installed-state verification.': '用于验证安装状态的在线检查。',
  'online inspection passed while component remains installed.': '在线检查通过，部件保持安装状态。',
  'post removal inspection required before reinstallation': '部件拆卸后需检查，检查通过后方可再次安装',
  'n/a': '未填写'
}

const positionMap = {
  'left engine position': '左侧发动机位置',
  'right engine position': '右侧发动机位置',
  'navigation bay': '导航舱',
  'hydraulic system bay': '液压系统舱',
  'main landing gear': '主起落架',
  nose: '机头',
  tail: '尾翼'
}

const categoryMap = {
  engine: '发动机',
  navigation: '导航',
  hydraulic: '液压',
  battery: '电池',
  avionics: '航电',
  landing_gear: '起落架'
}

export const formatComponentCategory = (value) => categoryMap[normalize(value)] || (normalize(value) === 'n/a' ? '未填写类别' : value || '-')

export const formatAircraftStatus = (value) => ({
  active: '服役中',
  maintenance: '维修中',
  retired: '已退役'
}[normalize(value)] || value || '-')

export const formatComponentStatus = (value) => ({
  in_stock: '在库',
  available: '可用',
  installed: '已安装',
  removed: '已拆卸',
  under_maintenance: '维修中',
  retired: '已退役'
}[normalize(value)] || value || '-')

export const formatInstallPosition = (value) => positionMap[normalize(value)] || value || '-'

export const formatMaintenanceType = (value) => maintenanceTypeMap[normalize(value)] || value || '-'

export const formatPlanType = (value) => formatMaintenanceType(value)

export const formatMaintenanceResult = (value) => ({
  pending: '待处理',
  passed: '通过',
  failed: '未通过',
  scrapped: '报废'
}[normalize(value)] || value || '-')

export const formatPlanStatus = (value) => ({
  pending: '待执行',
  completed: '已完成',
  cancelled: '已取消'
}[normalize(value)] || value || '-')

export const formatRetirementReason = (value) => retirementReasonMap[normalize(value)] || value || '未填写原因'

export const formatAuditOperationType = (value) => ({
  replace_component: '部件更换',
  component_replacement: '部件更换',
  retire_component: '部件退役',
  component_retirement: '部件退役',
  complete_maintenance: '完成维修',
  maintenance_completion: '完成维修',
  create_maintenance_plan: '创建维修计划',
  maintenance_plan_created: '创建维修计划',
  complete_maintenance_plan: '完成维修计划',
  maintenance_plan_completed: '完成维修计划',
  cancel_maintenance_plan: '取消维修计划',
  maintenance_plan_cancelled: '取消维修计划'
}[normalize(value)] || value || '未知操作')

export const formatLifecycleEventType = (value) => ({
  created: '入库',
  stock_in: '入库',
  in_stock: '入库',
  installed: '安装',
  installation: '安装',
  uninstalled: '拆卸',
  uninstallation: '拆卸',
  removed: '拆卸',
  maintenance_started: '维修开始',
  maintenance_start: '维修开始',
  maintenance_completed: '维修完成',
  maintenance_complete: '维修完成',
  maintenance_end: '维修完成',
  retired: '退役',
  retirement: '退役',
  maintenance_plan_created: '维修计划',
  maintenance_plan_completed: '计划完成',
  maintenance_plan_cancelled: '计划取消'
}[normalize(value)] || value || '其他事件')

export const formatBusinessText = (value) => {
  const mapped = commonTextMap[normalize(value)]
  if (mapped) return mapped
  const replacement = String(value ?? '').match(/^replacement for (.+)$/i)
  if (replacement) return `更换部件 ${replacement[1]}`
  return value || '-'
}

const formatPosition = (value) => normalize(value) === 'n/a' ? '未记录位置' : formatInstallPosition(value)
const formatCategory = (value) => formatComponentCategory(value)
const formatPerson = (value) => normalize(value) === 'n/a' ? '未记录' : value || '未记录'

export const formatAuditDetail = (detail) => {
  if (!detail) return '暂无操作详情'

  let match = detail.match(/^Completed maintenance for component (.+?); result: (.+)$/i)
  if (match) return `完成部件 ${match[1]} 的维修，结果：${formatMaintenanceResult(match[2])}`

  match = detail.match(/^Retired component (.+?); reason: (.+)$/i)
  if (match) return `部件 ${match[1]} 已退役，原因：${formatRetirementReason(match[2])}`

  match = detail.match(/^Replaced component (.+?) with (.+?) on aircraft (.+?) at (.+?)(?:; closed installation_id=\d+)?$/i)
  if (match) return `将飞机 ${match[3]} 的${formatPosition(match[4])}部件 ${match[1]} 更换为 ${match[2]}`

  match = detail.match(/^Created maintenance plan for component (.+?); type: (.+)$/i)
  if (match) return `为部件 ${match[1]} 创建维修计划，类型：${formatPlanType(match[2])}`

  match = detail.match(/^Completed maintenance plan for component (.+?); type: (.+)$/i)
  if (match) return `完成部件 ${match[1]} 的维修计划，类型：${formatPlanType(match[2])}`

  match = detail.match(/^Cancelled maintenance plan for component (.+?); type: (.+)$/i)
  if (match) return `取消部件 ${match[1]} 的维修计划，类型：${formatPlanType(match[2])}`

  return formatBusinessText(detail)
}

export const formatLifecycleTitle = (title, eventType) => ({
  'component entered inventory': '部件入库',
  'component installed': '部件安装',
  'component removed': '部件拆卸',
  'maintenance started': '维修开始',
  'maintenance completed': '维修完成',
  'component retired': '部件退役',
  'maintenance plan created': '维修计划创建',
  'maintenance plan completed': '维修计划完成',
  'maintenance plan cancelled': '维修计划取消'
}[normalize(title)] || title || formatLifecycleEventType(eventType))

export const formatLifecycleDetail = (detail, eventType) => {
  if (!detail) return '暂无事件详情'
  const type = normalize(eventType)
  let match

  if (['created', 'stock_in', 'in_stock'].includes(type)) {
    match = detail.match(/^Model: (.*?), category: (.*?), batch: (.*)$/i)
    if (match) return `型号：${match[1]}，类别：${formatCategory(match[2])}，批次：${formatBusinessText(match[3])}`
  }

  if (['installed', 'installation', 'uninstalled', 'uninstallation', 'removed'].includes(type)) {
    match = detail.match(/^Aircraft: (.*?), position: (.*?), reason: (.*)$/i)
    if (match) return `飞机：${match[1]}，位置：${formatPosition(match[2])}，原因：${formatBusinessText(match[3])}`
  }

  if (['maintenance_started', 'maintenance_start'].includes(type)) {
    match = detail.match(/^Type: (.*?), technician: (.*?), description: (.*)$/i)
    if (match) return `类型：${formatMaintenanceType(match[1])}，维修人员：${formatPerson(match[2])}，说明：${formatBusinessText(match[3])}`
  }

  if (['maintenance_completed', 'maintenance_complete', 'maintenance_end'].includes(type)) {
    match = detail.match(/^Type: (.*?), result: (.*?), description: (.*)$/i)
    if (match) return `类型：${formatMaintenanceType(match[1])}，结果：${formatMaintenanceResult(match[2])}，说明：${formatBusinessText(match[3])}`
  }

  if (['retired', 'retirement'].includes(type)) {
    match = detail.match(/^Reason: (.*?), approved by: (.*)$/i)
    if (match) return `原因：${formatRetirementReason(match[1])}，审批人：${formatPerson(match[2])}`
  }

  if (type === 'maintenance_plan_created') {
    match = detail.match(/^Type: (.*?), planned time: (.*?), reason: (.*)$/i)
    if (match) return `类型：${formatPlanType(match[1])}，计划时间：${match[2]}，原因：${formatBusinessText(match[3])}`
  }

  if (['maintenance_plan_completed', 'maintenance_plan_cancelled'].includes(type)) {
    match = detail.match(/^Type: (.*?), status: (.*?), related maintenance ID: (.*)$/i)
    if (match) return `类型：${formatPlanType(match[1])}，状态：${formatPlanStatus(match[2])}，关联维修记录 ID：${normalize(match[3]) === 'n/a' ? '无' : match[3]}`
  }

  return formatBusinessText(detail)
}
