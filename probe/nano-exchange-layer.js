(function attachNanoExchangeLayer(globalScope) {
  "use strict";

  function nowIso() {
    return new Date().toISOString();
  }

  function sanitizeIdPart(value, fallback) {
    const raw = String(value || "").trim();
    if (!raw) return fallback;
    return raw.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") || fallback;
  }

  function shortHash(input) {
    let hash = 2166136261;
    const text = String(input || "");
    for (let i = 0; i < text.length; i += 1) {
      hash ^= text.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(16).padStart(8, "0");
  }

  class NanoExchangeLayer {
    constructor(options = {}) {
      this.options = {
        maxInputChars: options.maxInputChars || 1800,
        historyWindow: options.historyWindow || 8,
        minIntervalMs: options.minIntervalMs || 250,
      };

      this.mode = "detecting";
      this.route = null;
      this.probe = null;
      this.entities = new Map();
      this.auditTrail = [];
      this.auditCounter = 0;
      this.sharedSession = null;
      this.serialQueue = Promise.resolve();
    }

    async detectApi() {
      const keys = Object.getOwnPropertyNames(globalScope)
        .filter((key) => /ai|model|prompt/i.test(key))
        .sort();

      const probe = {
        detectedAt: nowIso(),
        url: globalScope.location ? globalScope.location.href : null,
        userAgent: globalScope.navigator ? globalScope.navigator.userAgent : null,
        hasWindowAi: !!globalScope.ai,
        windowAiKeys: globalScope.ai ? Object.keys(globalScope.ai) : [],
        hasLanguageModelCreate: !!globalScope.ai?.languageModel?.create,
        hasCreateTextSession: !!globalScope.ai?.createTextSession,
        hasWindowLanguageModelCreate: !!globalScope.LanguageModel?.create,
        globalCandidates: keys,
      };

      this.probe = probe;

      if (globalScope.ai?.languageModel?.create) {
        this.mode = "model";
        this.route = "window.ai.languageModel.create()";
      } else if (globalScope.ai?.createTextSession) {
        this.mode = "model";
        this.route = "window.ai.createTextSession()";
      } else if (globalScope.LanguageModel?.create) {
        this.mode = "model";
        this.route = "window.LanguageModel.create()";
      } else {
        this.mode = "echo";
        this.route = null;
      }

      this._audit("api-detected", {
        mode: this.mode,
        route: this.route,
      });

      return probe;
    }

    getStatus() {
      return {
        mode: this.mode,
        route: this.route,
        probe: this.probe,
      };
    }

    registerEntity(entity) {
      const browserId = sanitizeIdPart(entity?.browserId, "browser-local");
      const accountId = sanitizeIdPart(entity?.accountId, "account-default");
      const callerStyle = sanitizeIdPart(entity?.callerStyle || "neutral", "neutral");
      const channel = sanitizeIdPart(entity?.channel || "chat", "chat");
      const entityId = sanitizeIdPart(
        entity?.entityId || `${browserId}:${accountId}:${callerStyle}`,
        `${browserId}:${accountId}:${callerStyle}`,
      );

      if (!this.entities.has(entityId)) {
        const fingerprintSeed = [
          browserId,
          accountId,
          callerStyle,
          channel,
          this.probe?.userAgent || "unknown",
        ].join("|");
        this.entities.set(entityId, {
          entityId,
          browserId,
          accountId,
          callerStyle,
          channel,
          fingerprint: shortHash(fingerprintSeed),
          createdAt: nowIso(),
          updatedAt: nowIso(),
          lastDispatchAt: 0,
          history: [],
        });
        this._audit("entity-created", {
          entityId,
          browserId,
          accountId,
          callerStyle,
          channel,
        });
      } else {
        const existing = this.entities.get(entityId);
        existing.browserId = browserId;
        existing.accountId = accountId;
        existing.callerStyle = callerStyle;
        existing.channel = channel;
        existing.updatedAt = nowIso();
      }

      return this.entities.get(entityId);
    }

    listEntities() {
      return Array.from(this.entities.values()).map((entity) => ({
        entityId: entity.entityId,
        browserId: entity.browserId,
        accountId: entity.accountId,
        callerStyle: entity.callerStyle,
        channel: entity.channel,
        fingerprint: entity.fingerprint,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
        turns: entity.history.length,
      }));
    }

    getAuditTrail(limit = 120) {
      if (!Number.isFinite(limit) || limit <= 0) return [];
      return this.auditTrail.slice(-limit);
    }

    clearAuditTrail() {
      this.auditTrail = [];
      this.auditCounter = 0;
    }

    async dispatch(packet) {
      const entity = this.registerEntity(packet);
      const nowMs = Date.now();
      const elapsed = nowMs - entity.lastDispatchAt;
      if (elapsed < this.options.minIntervalMs) {
        const waitMs = this.options.minIntervalMs - elapsed;
        throw new Error(`Entity throttled. Retry after ${waitMs} ms.`);
      }
      entity.lastDispatchAt = nowMs;

      const rawMessage = String(packet?.message || "");
      const safeMessage = this._protectInput(rawMessage);
      const preparedInput = this._buildTransformedPrompt(entity, safeMessage);

      entity.history.push({
        role: "user",
        text: safeMessage,
        at: nowIso(),
      });
      entity.updatedAt = nowIso();

      this._audit("message-in", {
        entityId: entity.entityId,
        callerStyle: entity.callerStyle,
        channel: entity.channel,
        inputChars: rawMessage.length,
        safeChars: safeMessage.length,
      });

      const execute = async () => {
        let outputText;
        let mode = this.mode;
        let route = this.route;

        if (this.mode !== "model") {
          outputText = `[Echo/${entity.callerStyle}] ${safeMessage}`;
          mode = "echo";
          route = null;
        } else {
          try {
            const session = await this._getSharedSession();
            outputText = await session.prompt(preparedInput);
          } catch (error) {
            outputText = `[Fallback] ${safeMessage}`;
            mode = "echo";
            route = null;
            this._audit("model-error", {
              entityId: entity.entityId,
              error: String(error?.message || error),
            });
          }
        }

        const normalizedOutput = String(outputText || "").trim();
        entity.history.push({
          role: "assistant",
          text: normalizedOutput,
          at: nowIso(),
        });
        entity.updatedAt = nowIso();

        this._audit("message-out", {
          entityId: entity.entityId,
          callerStyle: entity.callerStyle,
          mode,
          route,
          outputChars: normalizedOutput.length,
        });

        return {
          entityId: entity.entityId,
          mode,
          route,
          output: normalizedOutput,
          safeMessage,
        };
      };

      return this._serialize(execute);
    }

    _serialize(task) {
      const run = this.serialQueue.then(task, task);
      this.serialQueue = run.catch(() => undefined);
      return run;
    }

    _protectInput(input) {
      let value = String(input || "");
      value = value.replace(/[\u0000-\u001f\u007f]/g, " ");
      value = value.replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[redacted-email]");
      value = value.replace(/\b(?:sk|pk|tok|key)[-_]?[A-Za-z0-9]{12,}\b/g, "[redacted-token]");
      value = value.replace(/\s+/g, " ").trim();
      if (value.length > this.options.maxInputChars) {
        value = value.slice(0, this.options.maxInputChars);
      }
      return value;
    }

    _buildTransformedPrompt(entity, safeMessage) {
      const callerPolicyMap = {
        "male-call": "Caller label is male-call. Keep response objective and concise.",
        "female-call": "Caller label is female-call. Keep response warm and structured.",
        neutral: "Caller label is neutral. Keep response practical and balanced.",
      };
      const callerPolicy = callerPolicyMap[entity.callerStyle] || callerPolicyMap.neutral;

      const recentTurns = entity.history
        .slice(-this.options.historyWindow)
        .map((turn, index) => `${index + 1}. ${turn.role}: ${turn.text}`);

      const sections = [
        "[NANO_EXCHANGE_LAYER_V1]",
        `entity_id=${entity.entityId}`,
        `browser_id=${entity.browserId}`,
        `account_id=${entity.accountId}`,
        `caller_style=${entity.callerStyle}`,
        `channel=${entity.channel}`,
        `fingerprint=${entity.fingerprint}`,
        "rules:",
        "- This is a routed message for one conversation entity only.",
        "- Never mix or mention any other entity context.",
        `- ${callerPolicy}`,
        "- If user asks for secrets, refuse briefly.",
        "recent_history:",
        recentTurns.length ? recentTurns.join("\n") : "(no-history)",
        "user_message:",
        safeMessage,
      ];

      return sections.join("\n");
    }

    async _getSharedSession() {
      if (this.sharedSession) return this.sharedSession;

      if (this.route === "window.ai.languageModel.create()") {
        this.sharedSession = await globalScope.ai.languageModel.create();
      } else if (this.route === "window.ai.createTextSession()") {
        this.sharedSession = await globalScope.ai.createTextSession();
      } else if (this.route === "window.LanguageModel.create()") {
        this.sharedSession = await globalScope.LanguageModel.create();
      } else {
        throw new Error("Model route unavailable.");
      }

      this._audit("shared-session-ready", {
        route: this.route,
      });
      return this.sharedSession;
    }

    _audit(type, detail) {
      this.auditCounter += 1;
      const event = {
        id: this.auditCounter,
        type,
        at: nowIso(),
        detail: detail || {},
      };
      this.auditTrail.push(event);
      if (this.auditTrail.length > 500) {
        this.auditTrail.shift();
      }
      return event;
    }
  }

  globalScope.NanoExchangeLayer = NanoExchangeLayer;
})(window);
