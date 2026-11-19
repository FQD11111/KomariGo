package com.lcdcxp.komarigo

import androidx.compose.ui.graphics.Color

/**
 * 三网线路评级
 *
 * 综合三网（电信 / 联通 / 移动）的平均延迟与丢包率，输出 0–100 分与六档评价。
 * 基准分由平均延迟映射，丢包按比例扣分（上限 25 分）。
 */
object LineRate {

    // 档位定义：最低分 → 名称
    private val LEVELS = listOf(
        92 to "丝滑",
        80 to "优秀",
        68 to "良好",
        54 to "一般",
        38 to "拥塞",
        -1 to "劣化"
    )

    /** 平均延迟 → 基准分 */
    private fun baseScore(ms: Double): Int = when {
        ms <= 20 -> 98
        ms <= 30 -> 95
        ms <= 45 -> 90
        ms <= 65 -> 83
        ms <= 90 -> 78
        ms <= 120 -> 70
        ms <= 160 -> 60
        ms <= 220 -> 50
        ms <= 300 -> 40
        ms <= 450 -> 28
        else -> 12
    }

    fun levelName(score: Int): String =
        LEVELS.firstOrNull { score >= it.first }?.second ?: "劣化"

    /** 档位主色 */
    fun levelColor(name: String): Color = when (name) {
        "丝滑" -> C.ok
        "优秀" -> C.accent
        "良好" -> C.cpu
        "一般" -> C.warn
        "拥塞" -> Color(0xFFC2410C)
        else -> C.bad
    }

    /** 档位底色（浅色主题） */
    fun levelBg(name: String): Color = when (name) {
        "丝滑" -> C.okBg
        "优秀" -> if (C.isLight) Color(0xFFE7F1FC) else Color(0xFF12233A)
        "良好" -> if (C.isLight) Color(0xFFE4F5F3) else Color(0xFF10292A)
        "一般" -> if (C.isLight) Color(0xFFFBF2DF) else Color(0xFF2B2411)
        "拥塞" -> if (C.isLight) Color(0xFFFCEEE4) else Color(0xFF2E1A10)
        else -> C.badBg
    }

    /**
     * 计算某台节点的三网评级。
     *
     * @param stats 该节点的探测任务列表（面板返回）
     * @return 评分结果；无有效数据时返回 null
     */
    fun of(stats: List<Ping>): Result? {
        if (stats.isEmpty()) return null
        // 归并到固定三栏，只取有有效延迟的
        val valid = threeCarriersPublic(stats).mapNotNull { it.second }.filter { it.avg > 0 }
        if (valid.isEmpty()) return null

        val mean = valid.sumOf { it.avg } / valid.size
        val loss = valid.sumOf { it.loss } / valid.size
        val penalty = minOf(25.0, loss * 3.0)
        val score = (baseScore(mean) - penalty).toInt().coerceIn(0, 100)
        val name = levelName(score)
        return Result(
            score = score,
            name = name,
            meanMs = mean.toInt(),
            lossPct = loss,
            covered = valid.size,
            color = levelColor(name),
            bg = levelBg(name)
        )
    }

    data class Result(
        val score: Int,
        val name: String,
        val meanMs: Int,
        val lossPct: Double,
        val covered: Int,
        val color: Color,
        val bg: Color
    )
}

/** 供 LineRate 使用的三网归并（与 UI 中渲染三栏的逻辑一致） */
fun threeCarriersPublic(stats: List<Ping>): List<Pair<String, Ping?>> {
    val order = listOf("电信", "联通", "移动")
    val by = stats.groupBy { carrierNamePublic(it.name) }
    return order.map { c ->
        c to by[c]?.minByOrNull { if (it.avg <= 0) Double.MAX_VALUE else it.avg }
    }
}

fun carrierNamePublic(n: String): String = when {
    n.contains("电信") -> "电信"
    n.contains("联通") -> "联通"
    n.contains("移动") -> "移动"
    else -> "其他"
}
