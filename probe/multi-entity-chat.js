const $ = (id) => document.getElementById(id);

const exchange = new window.NanoExchangeLayer({
  maxInputChars: 1200,
  historyWindow: 6,
  minIntervalMs: 220,
});

const entities = [
  {
    key: "male-a",
    title: "男來電 A",
    browserId: "browser-a",
    accountId: "user-m-001",
    callerStyle: "male-call",
    channel: "group-room",
    sample: "我是男來電 A，請用三點整理今天要完成的工作。",
  },
  {
    key: "female-b",
    title: "女來電 B",
    browserId: "browser-b",
    accountId: "user-f-204",
    callerStyle: "female-call",
    channel: "group-room",
    sample: "我是女來電 B，幫我把剛剛的內容改成條列式行動清單。",
  },
  {
    key: "supervisor-c",
    title: "主管 C",
    browserId: "browser-c",
    accountId: "manager-009",
    callerStyle: "neutral",
    channel: "group-room",
    sample: "我是主管 C，請對 A 與 B 的需求做整合回覆，且不要混淆身分。",
  },
];

function nowText() {
  return new Date().toLocaleTimeString();
}

function renderStatus() {
  const status = exchange.getStatus();
  const el = $("status");
  if (status.mode === "model") {
    el.textContent = `Model mode (${status.route})`;
    el.style.background = "#e8f7ee";
    el.style.color = "#117746";
  } else {
    el.textContent = "Echo mode (no model API)";
    el.style.background = "#fff5e5";
    el.style.color = "#8f6011";
  }
}

function addTurn(role, entityTitle, text, extra = "") {
  const line = document.createElement("div");
  line.className = `turn ${role}`;

  const meta = document.createElement("div");
  meta.className = "turn-meta";
  meta.textContent = `${role === "user" ? "User" : "Bot"} • ${entityTitle} • ${nowText()}${extra ? ` • ${extra}` : ""}`;

  const body = document.createElement("div");
  body.textContent = text;

  line.appendChild(meta);
  line.appendChild(body);
  $("timeline").appendChild(line);
  $("timeline").scrollTop = $("timeline").scrollHeight;
}

function renderAuditAndEntities() {
  $("auditJson").textContent = JSON.stringify(exchange.getAuditTrail(160), null, 2);
  $("entitiesJson").textContent = JSON.stringify(exchange.listEntities(), null, 2);
}

async function sendFromEntity(entity, message) {
  addTurn("user", entity.title, message, entity.callerStyle);

  try {
    const result = await exchange.dispatch({
      entityId: `${entity.browserId}:${entity.accountId}:${entity.callerStyle}`,
      browserId: entity.browserId,
      accountId: entity.accountId,
      callerStyle: entity.callerStyle,
      channel: entity.channel,
      message,
    });
    const modeTag = result.mode === "model" ? result.route : "echo";
    addTurn("bot", entity.title, result.output, modeTag);
  } catch (error) {
    addTurn("bot", entity.title, `Error: ${String(error?.message || error)}`, "error");
  }

  renderAuditAndEntities();
}

function createCard(entity) {
  const card = document.createElement("article");
  card.className = "entity-card";

  card.innerHTML = `
    <h2 class="entity-title">
      ${entity.title}
      <span class="pill">${entity.callerStyle}</span>
    </h2>
    <div class="meta">${entity.browserId} / ${entity.accountId} / ${entity.channel}</div>
    <textarea id="input-${entity.key}" placeholder="輸入 ${entity.title} 訊息">${entity.sample}</textarea>
    <div class="actions">
      <button id="send-${entity.key}">送出</button>
      <button id="preset-${entity.key}" class="secondary">回填範例</button>
    </div>
  `;

  return card;
}

function bindCards() {
  const container = $("entityCards");
  entities.forEach((entity) => {
    container.appendChild(createCard(entity));

    $(`send-${entity.key}`).addEventListener("click", async () => {
      const value = $(`input-${entity.key}`).value.trim();
      if (!value) return;
      await sendFromEntity(entity, value);
    });

    $(`preset-${entity.key}`).addEventListener("click", () => {
      $(`input-${entity.key}`).value = entity.sample;
    });
  });
}

async function runScenario() {
  const sequence = [
    [entities[0], entities[0].sample],
    [entities[1], entities[1].sample],
    [entities[0], "請延續男來電 A 的對話，不要提到 B 的資訊。"],
    [entities[2], entities[2].sample],
    [entities[1], "延續女來電 B 內容，且不可誤用 A 的脈絡。"],
  ];

  for (const [entity, message] of sequence) {
    await sendFromEntity(entity, message);
  }
}

$("btnRunScenario").addEventListener("click", runScenario);
$("btnClear").addEventListener("click", () => {
  $("timeline").innerHTML = "";
  addTurn("bot", "System", "Timeline cleared.");
});

async function init() {
  await exchange.detectApi();
  renderStatus();
  bindCards();
  renderAuditAndEntities();

  addTurn(
    "bot",
    "System",
    exchange.getStatus().mode === "model"
      ? "Model API detected. Multi-entity switch mode is active."
      : "Model API unavailable. Echo fallback is active.",
  );
}

init();
