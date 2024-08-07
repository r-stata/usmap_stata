* shp2dta
cd "/Users/ac/Desktop/使用 Stata 绘制美国州县地图/"
local name = "mainus_alaska_hawaii"
shp2dta using `name'/`name'.shp, database(`name'_db) coordinates(`name'_coord) replace genid(ID)

* shp 转 dta 
local name = "us_states_withns"
shp2dta using `name'/`name'.shp, database(`name'_db) coordinates(`name'_coord) replace genid(ID)
shp2dta using `name'/`name'_line.shp, database(`name'_line_db) coordinates(`name'_line_coord) replace genid(ID)

local name = "us_counties_withns"
shp2dta using `name'/`name'.shp, database(`name'_db) coordinates(`name'_coord) replace genid(ID)
shp2dta using `name'/`name'_line.shp, database(`name'_line_db) coordinates(`name'_line_coord) replace genid(ID)

* 简单处理下
use us_states_withns_db.dta, clear 
keep if inlist(fips, "northarrow", "scale")
* 可以看到指北针和比例尺的 ID 是 53 和 54 

use us_states_withns_coord.dta, clear 
keep if inlist(_ID, 53, 54)
gen value = 1 
save uspolygon, replace 

use us_states_withns_db.dta, clear 
drop if inlist(fips, "northarrow", "scale")
save us_states_withns_db.dta, replace 

use us_states_withns_line_db.dta, clear 
* 这里我们把线条分为三类，一类是州界，一类是比例尺和指北针，最后一类是分隔线
use us_states_withns_line_coord.dta, clear 
gen group = 1
replace group = 2 if inlist(_ID, 53, 54, 55, 56)
replace group = 3 if inlist(_ID, 57)
save us_states_withns_line_coord.dta, replace

* 区县地图也可以使用州级地图的线条和 uspolygon.dta，所以就不必额外处理了：

use us_counties_withns_db.dta, clear 
drop if inlist(fips, "northarrow", "scale")
save us_counties_withns_db.dta, replace  

* 散点坐标变换

import delimited using "global_power_plant_database_v_1_3/global_power_plant_database.csv", clear 
* 判断哪些点属于 mainus/alaska/hawaii
geoinpoly latitude longitude using mainus_alaska_hawaii_coord.dta 
drop if mi(_ID)
ren _ID ID 
merge m:1 ID using mainus_alaska_hawaii_db.dta
* 边界的点可能会判断错误，删除不属于美国的发电厂
drop if country != "USA"
keep gppd_idnr capacity_mw class latitude longitude
save points, replace 

* 经纬度坐标转 laea 坐标
* albers_proj = "+proj=laea +lat_0=45 +lon_0=-100 +x_0=0 +y_0=0 +a=6370997 +b=6370997 +units=m +no_defs"

use points.dta, clear 
laea_projection longitude latitude x y
save points2, replace 

* 对阿拉斯加的散点进行特定的坐标变换
use points2.dta, clear 
keep if class == "alaska"
mkmat x y, mat(xymat)
mat rotate_mat = (0.6427876, 0.7660444 \ -0.7660444, 0.6427876)
mat newmat = xymat * rotate_mat 
svmat newmat
drop x y 
ren (newmat1 newmat2) (x y)
replace x = x/2 + 300000
replace y = y/2 - 2000000
save alaska_points, replace 

* 对夏威夷的也进行变换
use points2.dta, clear 
keep if class == "hawaii"
mkmat x y, mat(xymat)
mat rotate_mat = (0.8191520, 0.5735764 \ -0.5735764, 0.8191520)
mat newmat = xymat * rotate_mat 
svmat newmat
drop x y 
ren (newmat1 newmat2) (x y)
replace x = x/2 + 3600000
replace y = y/2 + 1800000
save hawaii_points, replace 

* 合并三部分散点
use points2.dta, clear 
keep if class == "mainus"
append using alaska_points 
append using hawaii_points 
egen group = cut(capacity_mw), group(8) label
tab group 
save points_all, replace 

* 然后就可以绘图了
use us_states_withns_db.dta, clear 
spmap using us_states_withns_coord, id(ID) ///
	line(data(us_states_withns_line_coord.dta) ///
		by(group) size(vvvthin vthin vthin) ///
		pattern(solid solid dash)) ///
	point(data(points_all) x(x) y(y) by(group) ///
		fcolor("158 176 255%60" "71 153 201%60" "34 87 113%60" ///
			"15 28 36%60" "44 14 0%60" "104 36 15%60" ///
			"179 101 86%60" "255 172 172%60") ///
		proportional(capacity_mw) size(*0.3 ...) ///
		legenda(on)) ///
	polygon(data(uspolygon) fc(black ...)) ///
	label(data(usmap_labeldf) x(X) y(Y) label(abbr) size(*0.8)) ///
	legend(order(7 "1~1.6" 8 "1.6~2.6" 9 "2.6~4.9" ///
				10 "4.9~8.15" 11 "8.15~20" 12 "20~65" ///
				13 "65~201" 14 ">201") ///
			ti("Capacity(MW)", size(*0.5)) ///
			pos(3) col(1) ring(0)) ///
	ti("Geographical distribution and power generation capacity" "of power plants in the United States") ///
	subti("Data processing & drawing: RStata's Official Account on WeChat") ///
	caption("Data Source: Global Power Plant Database" "<https://datasets.wri.org/dataset/globalpowerplantdatabase>", size(*0.8)) ///
	xsize(20) ysize(14) graphr(margin(medium))

gr export pic1.png, width(4800) replace 

* 绘制填充地图
use us_counties_withns_db.dta, clear 
merge 1:1 fips using "2022年美国各县平均PM2.5浓度.dta"
drop _m 
egen group = cut(PM25), group(8) label 
tab group 

* 区县地图也建议使用 us_states_withns_line_coord.dta 线条
spmap group using us_counties_withns_coord, id(ID) ///
	clmethod(unique) osize(vvvthin ...) ocolor(white ...) /// 
	fc("45 32 76" "84 66 110" "130 94 138" "173 103 149" "210 126 167" "210 159 191" "216 192 214" "229 229 240") /// 
	line(data(us_states_withns_line_coord.dta) ///
		by(group) size(vthin vthin vthin) ///
		pattern(solid solid dash)) ///
	polygon(data(uspolygon) fc(black ...)) ///
	label(data(usmap_labeldf) x(X) y(Y) label(abbr) size(*0.8)) ///
	legend(order(2 "0.48~4.16" 3 "4.16~5.19" 4 "5.19~5.86" ///
				5 "5.86~6.38" 6 "6.38~6.82" 7 "6.82~7.26" ///
				8 "7.26~7.98" 9 ">7.98") ///
			ti("PM2.5(µg/m3)", size(*0.5)) ///
			pos(3) col(1) ring(0)) ///
	ti("PM2.5 mass concentration of the United States in 2022") ///
	subti("Data processing & drawing: RStata's Official Account on WeChat") ///
	caption("Data Source: Satellite-derived PM2.5 | Atmospheric Composition Analysis Group | Washington University in St. Louis" "<https://sites.wustl.edu/acag/datasets/surface-pm2-5/>", size(*0.8)) ///
	xsize(20) ysize(14) graphr(margin(medium))

gr export pic2.png, width(4800) replace 
