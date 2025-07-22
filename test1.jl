# ================= 0. 环境 =================
using PowerModels
using PowerPlots
using ColorSchemes
using Setfield
using JuMP, Ipopt, VegaLite, ImageIO, ImageMagick, NodeJS

# ================= 1. 加载算例 =================
case = parse_file(joinpath(@__DIR__, "data", "case14.m"))

# ================= 2. 运行 OPF =================
result = solve_ac_opf(case, optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0))
update_data!(case, result["solution"])

# ================= 3. 修复缺失字段 =================
# 为 branch 补齐 rate_a（缺省 1.0 p.u.），防止除零
for (_, b) in case["branch"]
    b["rate_a"] = get(b, "rate_a", 1.0)
end

# ================= 4. 绘图 =================
p = powerplot(case,
    gen = (:data => :pg, :data_type => :quantitative, :color => ["black", "purple", "red"]),
    branch = (
        :data => :pt, :data_type => :quantitative, :color => ["black", "purple", "red"],
        :flow_arrow_size_range => [0, 4000], :show_flow => true,
    ),
    load = (:color => "#273D94"), bus = (:color => "#504F4F")
)

# ---------------- 5. 图层细节 ----------------
# 箭头颜色
p.layer[1]["layer"][2]["mark"]["color"] = :white
p.layer[1]["layer"][2]["mark"]["stroke"] = :black

# 支路利用率 &功率
p.layer[1]["transform"] = Dict{String, Any}[
    Dict("calculate" => "abs(datum.pt)/datum.rate_a*100", "as" => "branch_Percent_Loading"),
    Dict("calculate" => "abs(datum.pt)", "as" => "BranchPower")
]
p.layer[1]["layer"][1]["encoding"]["color"]["field"] = "branch_Percent_Loading"
p.layer[1]["layer"][1]["encoding"]["color"]["title"] = "Branch Utilization %"
p.layer[1]["layer"][1]["encoding"]["color"]["scale"]["domain"] = [0, 100]

# 发电机利用率 &容量
p.layer[4]["transform"] = Dict{String, Any}[
    Dict("calculate" => "datum.pg/(datum.pmax+1e-9)*100", "as" => "gen_Percent_Loading"),
    Dict("calculate" => "datum.pmax", "as" => "GenPower")
]
p.layer[4]["encoding"]["color"]["field"] = "gen_Percent_Loading"
p.layer[4]["encoding"]["color"]["scale"]["domain"] = [0, 100]
p.layer[4]["encoding"]["color"]["title"] = "Gen Utilization %"
p.layer[4]["encoding"]["size"] = Dict(
    "field" => "GenPower", "title" => "Gen Capacity [p.u.]",
    "type" => "quantitative", "scale" => Dict("range" => [50, 1000])
)

# 负荷形状 &大小
p.layer[5]["encoding"]["size"] = Dict(
    "field" => "pd", "title" => "Load Demand [p.u]",
    "type" => "quantitative", "scale" => Dict("range" => [50, 1000])
)
p.layer[5]["mark"]["type"] = :square

# 图例位置
p.layer[1]["layer"][1]["encoding"]["color"]["legend"] = Dict("orient" => "bottom-right", "offset" => -30)
p.layer[4]["encoding"]["color"]["legend"] = Dict("orient" => "bottom-right")

# 独立/共享比例尺
@set! p.resolve.scale.size = :independent
@set! p.resolve.scale.color = :shared

# ================= 6. 显示 & 保存 =================
p
VegaLite.save("result.svg", p)   # 已安装 ImageMagick/ImageIO，可直接保存 PNG