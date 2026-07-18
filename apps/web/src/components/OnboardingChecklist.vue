<template>
  <CardPanel v-if="visible" title="新手三步完成首次成功" class="onboarding-card">
    <div class="onboarding-head">
      <div>
        <b>{{ completedCount }}/{{ steps.length }} 已完成</b>
        <p>建议按顺序完成账号绑定、商品同步和自动化配置，先跑通一个最小运营闭环。</p>
      </div>
      <div class="onboarding-progress" :style="{ '--progress': `${progress}%` }"><span>{{ progress }}%</span></div>
    </div>
    <div class="onboarding-steps">
      <button
        v-for="step in steps"
        :key="step.key"
        type="button"
        :class="['onboarding-step', { done: isDone(step.key) }]"
        @click="go(step)"
      >
        <span class="step-check">{{ isDone(step.key) ? '✓' : step.order }}</span>
        <span><b>{{ step.title }}</b><em>{{ step.desc }}</em></span>
        <strong>{{ step.cta }} ›</strong>
      </button>
    </div>
    <div class="onboarding-actions">
      <button type="button" class="link" @click="markDone('seen-guide')">我已阅读指南</button>
      <button type="button" class="link danger" @click="onDismiss">不再提示</button>
    </div>
  </CardPanel>
</template>

<script setup>
import { computed, ref, onMounted } from 'vue'
import CardPanel from './CardPanel.vue'
import { getRuntimeStatus } from '../api/system.js'
import {
  isOnboardingDismissed,
  dismissOnboarding,
  getDoneKeys,
  markStepDone,
} from '../utils/onboardingState.js'

const emit = defineEmits(['navigate'])
const visible = ref(false)
const done = ref(getDoneKeys())

const steps = [
  { order: 1, key: 'account', title: '添加闲鱼账号', desc: '扫码或手动 Cookie 添加一个可用账号。', cta: '去添加', to: 'accounts' },
  { order: 2, key: 'sync', title: '同步线上商品', desc: '进入商品管理，同步账号下的在售商品。', cta: '去同步', to: 'products' },
  { order: 3, key: 'automation', title: '开启自动化', desc: '创建一条自动回复或自动发货规则并先用预览验证。', cta: '去配置', to: 'auto-reply' }
]

const isDone = key => done.value.includes(key)
const completedCount = computed(() => steps.filter(s => isDone(s.key)).length)
const progress = computed(() => Math.round((completedCount.value / steps.length) * 100))

function go(step) {
  markStepDone(step.key)
  done.value = getDoneKeys()
  emit('navigate', step.to)
}

function markDone(key) {
  markStepDone(key)
  done.value = getDoneKeys()
}

function onDismiss() {
  dismissOnboarding()
  visible.value = false
}

async function checkCompletionFromServer() {
  try {
    const res = await getRuntimeStatus()
    const data = res?.data || {}
    // 模型已配置视为"配置自动化"完成
    if (data.generalModelConfigured) markStepDone('automation')
    // 数据库连通视为已通过基础环境检查
    if (data.dbConnected) markStepDone('seen-guide')
    done.value = getDoneKeys()
  } catch {
    // 静默失败，不影响用户首次使用
  }
}

onMounted(() => {
  if (isOnboardingDismissed()) {
    visible.value = false
    return
  }
  // 完成所有步骤后不再显示
  if (completedCount.value >= steps.length) {
    visible.value = false
    return
  }
  visible.value = true
  checkCompletionFromServer()
})
</script>

<style scoped>
.onboarding-card { margin-bottom: 16px; }
.onboarding-head{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:16px}.onboarding-head b{font-size:18px;color:#16213e}.onboarding-head p{margin:6px 0 0;color:#667085;line-height:1.7}.onboarding-progress{--progress:0%;width:72px;height:72px;border-radius:50%;background:conic-gradient(#0d6bff var(--progress),#edf2fb 0);display:flex;align-items:center;justify-content:center;flex:0 0 auto}.onboarding-progress span{width:54px;height:54px;border-radius:50%;background:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;color:#0d6bff}.onboarding-steps{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.onboarding-step{display:flex;align-items:flex-start;gap:12px;text-align:left;border:1px solid #e8eef8;background:#fff;border-radius:16px;padding:14px;cursor:pointer;transition:.16s}.onboarding-step:hover{border-color:#bfd7ff;box-shadow:0 12px 30px rgba(13,107,255,.08);transform:translateY(-1px)}.onboarding-step.done{background:#f4fff8;border-color:#abefc6}.step-check{width:28px;height:28px;border-radius:10px;background:#edf4ff;color:#0d6bff;display:flex;align-items:center;justify-content:center;font-weight:900;flex:0 0 auto}.done .step-check{background:#dcfae6;color:#067647}.onboarding-step span:nth-child(2){flex:1}.onboarding-step b{display:block;color:#16213e}.onboarding-step em{display:block;margin-top:5px;color:#667085;font-style:normal;line-height:1.5}.onboarding-step strong{color:#0d6bff;white-space:nowrap;font-size:13px}.onboarding-actions{display:flex;justify-content:flex-end;gap:14px;margin-top:12px}.onboarding-actions .link{background:transparent;border:0;color:#64748b;font-size:12px;cursor:pointer;padding:4px 8px;border-radius:6px}.onboarding-actions .link:hover{background:#f1f5f9;color:#0f172a}.onboarding-actions .link.danger:hover{color:#dc2626}@media(max-width:1100px){.onboarding-steps{grid-template-columns:minmax(0, 1fr)}.onboarding-steps > *{min-width:0}}
</style>
