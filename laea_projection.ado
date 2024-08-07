*! 微信公众号 RStata 
program define laea_projection
    display "程序编写：微信公众号 RStata"
    args lon lat x y

    // 设置投影参数
    local lat0 = 45 * _pi / 180
    local lon0 = -100 * _pi / 180
    local R = 6370997

    // 将经纬度转换为弧度
    tempvar lon_rad lat_rad
    gen `lon_rad' = `lon' * _pi / 180
    gen `lat_rad' = `lat' * _pi / 180

    // 计算辅助变量
    tempvar k rho
    gen `k' = sqrt(2 / (1 + sin(`lat0') * sin(`lat_rad') + cos(`lat0') * cos(`lat_rad') * cos(`lon_rad' - `lon0')))

    // 计算投影坐标
    gen `x' = `R' * `k' * cos(`lat_rad') * sin(`lon_rad' - `lon0')
    gen `y' = `R' * `k' * (cos(`lat0') * sin(`lat_rad') - sin(`lat0') * cos(`lat_rad') * cos(`lon_rad' - `lon0'))
end
