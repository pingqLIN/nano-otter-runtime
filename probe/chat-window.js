const $ = (id) => document.getElementById(id);

const exchange = new window.NanoExchangeLayer({
  maxInputChars: 1800,
  historyWindow: 8,
  minIntervalMs: 240,
});

function nowText() {
  return new Date().toLocaleTimeString();
}

function entityDraft() {
  return {
    browserId: $("browserId").value.trim() || "browser-a",
    accountId: $("accountId").value.trim() || "user-001",
    callerStyle: $("callerStyle").value,
    channel: $("channel").value.trim() || "web-chat",
    entityId: $("entityId").value.trim() || undefined,
  };
}

function refreshEntityTag() {
  const draft = entityDraft();
  const entity = exchange.registerEntity(draft);
  $("currentEntity").textContent = `entity: ${entity.entityId} (${entity.callerStyle})`;
  return entity;
}

function setStatus() {
  const status = exchange.getStatus();
  const el = $("status");
  if (status.mode === "model") {
    el.className = "status ok";
    el.textContent = `Model mode (${status.route})`;
  } else if (status.mode === "echo") {
    el.className = "status warn";
    el.textContent = "Echo mode (no model API)";
  } else {
    el.className = "status warn";
    el.textContent = "Detecting API...";
  }
}

function addMessage(role, text, extra = "") {
  const chat = $("chat");
  const item = document.createElement("div");
  item.className = `msg ${role}`;

  const meta = document.createElement("div");
  meta.className = "meta";
  meta.textContent = `${role === "user" ? "You" : "Bot"} • ${nowText()}${extra ? ` • ${extra}` : ""}`;

  const body = document.createElement("div");
  body.textContent = text;

  item.appendChild(meta);
  item.appendChild(body);
  chat.appendChild(item);
  chat.scrollTop = chat.scrollHeight;
}

function renderProbe() {
  $("probeJson").textContent = JSON.stringify(exchange.getStatus(), null, 2);
}

function renderAudit() {
  const audit = exchange.getAuditTrail(120);
  const entities = exchange.listEntities();
  $("auditJson").textContent = JSON.stringify({ entities, audit }, null, 2);
}

async function send() {
  const text = $("prompt").value.trim();
  if (!text) return;

  const entity = refreshEntityTag();
  addMessage("user", text, entity.entityId);
  $("prompt").value = "";

  try {
    const result = await exchange.dispatch({
      ...entity,
      message: text,
    });
    const modeTag = result.mode === "model" ? result.route : "echo";
    addMessage("bot", result.output, `${result.entityId} • ${modeTag}`);
  } catch (error) {
    addMessage("bot", `Error: ${String(error?.message || error)}`, "error");
  }

  renderAudit();
}

function bindEntityInputs() {
  ["browserId", "accountId", "callerStyle", "channel", "entityId"].forEach((id) => {
    $(id).addEventListener("input", refreshEntityTag);
    $(id).addEventListener("change", refreshEntityTag);
  });
}

$("btnSend").addEventListener("click", send);
$("btnSelfTest").addEventListener("click", async () => {
  $("prompt").value = "請用 1 句話回覆：exchange-layer-test-ok";
  await send();
});
$("btnClear").addEventListener("click", () => {
  $("chat").innerHTML = "";
  addMessage("bot", "Chat cleared.");
});
$("btnProbe").addEventListener("click", () => {
  const pre = $("probeJson");
  pre.style.display = pre.style.display === "block" ? "none" : "block";
});
$("btnAudit").addEventListener("click", () => {
  const pre = $("auditJson");
  pre.style.display = pre.style.display === "block" ? "none" : "block";
  renderAudit();
});
$("btnMale").addEventListener("click", () => {
  $("callerStyle").value = "male-call";
  refreshEntityTag();
  addMessage("bot", "已切換為男來電封包規則。", "switch");
});
$("btnFemale").addEventListener("click", () => {
  $("callerStyle").value = "female-call";
  refreshEntityTag();
  addMessage("bot", "已切換為女來電封包規則。", "switch");
});

$("prompt").addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    send();
  }
});

async function init() {
  await exchange.detectApi();
  setStatus();
  bindEntityInputs();
  refreshEntityTag();
  renderProbe();
  renderAudit();
  addMessage(
    "bot",
    exchange.getStatus().mode === "model"
      ? "Model API detected. Routed mode is active."
      : "Model API not detected. Echo fallback is active.",
  );
}

init();
