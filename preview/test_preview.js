const chromium = require('@sparticuz/chromium').default || require('@sparticuz/chromium');
const puppeteer = require('puppeteer-core');
let pass = 0, fail = 0;
const ok = (c, m) => { if (c) pass++; else { fail++; console.log('FAIL:', m); } };
(async () => {
  const browser = await puppeteer.launch({ args: [...chromium.args, '--no-sandbox'], executablePath: await chromium.executablePath(), headless: 'shell' });
  const page = await browser.newPage(); await page.setViewport({ width: 390, height: 844 });
  const errs = []; page.on('pageerror', e => errs.push(String(e).slice(0, 200)));
  await page.goto('file:///home/claude/work/indie/indie_preview.html', { waitUntil: 'load' });
  const ev = (js) => page.evaluate(js), wait = ms => new Promise(r => setTimeout(r, ms));
  const click = async sel => { await page.click(sel); await wait(120); };

  // --- onboarding flow (real clicks) ---
  ok(await ev("!document.querySelector('#tabbar').offsetParent || getComputedStyle(document.querySelector('#tabbar')).display==='none'"), 'tab bar hidden on welcome');
  await page.click('#pg-welcome .btn.primary'); await wait(400);
  await page.type('#idInput', 'admin'); ok(await ev("$('#fId').classList.contains('bad')"), 'taken ID is rejected');
  await page.$eval('#idInput', e => e.value = ''); await page.type('#idInput', 'my.new_id'); ok(await ev("$('#fId').classList.contains('good')"), 'valid ID accepted');
  await page.click('#pg-createid .btn.primary'); await wait(300); ok(await ev("$('#fPin').classList.contains('bad')"), 'PIN < 6 rejected');
  await page.type('#pinInput', '123456'); await page.click('#pg-createid .btn.primary'); await wait(400);
  ok(await ev("$$('#wordGrid div').length===12"), '12 phrase words shown');
  await page.click('#pg-phrase .btn.primary'); await wait(200); ok(await ev("$('#pg-phrase').classList.contains('open')"), 'cannot continue before confirming phrase');
  await click('#phraseRow'); await page.click('#pg-phrase .btn.primary'); await wait(500);
  ok(await ev("ME.id==='my.new_id' && !stack.length"), 'account created, entered app'); ok(await ev("getComputedStyle($('#tabbar')).display!=='none'"), 'tab bar visible in app');

  // --- unified messages list + filters ---
  ok(await ev("$$('#chatList .row').length>=8"), 'messages list populated (people+agents+group+orchestrator)');
  await ev("msgFilter='agents';renderMessages()"); ok(await ev("$$('#chatList .row').every(r=>/Agent|Coach|Assistant|Creator|Orchestrator/.test(r.textContent))"), 'Agents filter shows only agents');
  await ev("msgFilter='groups';renderMessages()"); ok(await ev("$$('#chatList .row').length===2"), 'Groups filter shows 2 groups');
  await ev("msgFilter='all';renderMessages()");

  // --- chat: send, reply, react, delete ---
  await ev("openChat('p2')"); await wait(350); await page.type('#chInput', 'Hello Sarah'); await page.keyboard.press('Enter'); await wait(300);
  ok(await ev("curChat.messages.at(-1).t==='Hello Sarah'"), 'message sent');
  await wait(2600); ok(await ev("curChat.messages.at(-1).me===false && curChat.unread===0"), 'reply arrives while chat is open, no unread');
  const mid1 = await ev("curChat.messages.find(m=>m.t==='Hello Sarah').id");
  await ev(`openMsg('chat','${mid1}')`); await ev("startReply()"); ok(await ev("$('#chReply').classList.contains('show')"), 'reply bar shown');
  await page.type('#chInput', 'quoted'); await page.keyboard.press('Enter'); await wait(200); ok(await ev("!!curChat.messages.find(m=>m.t==='quoted').replyTo"), 'reply quote attached');
  await ev(`react('chat','${mid1}','👍')`); ok(await ev(`findMsg('chat','${mid1}').rx['👍']===1`), 'reaction added'); await ev(`react('chat','${mid1}','👍')`); ok(await ev(`!findMsg('chat','${mid1}').rx`) || await ev(`!findMsg('chat','${mid1}').rx['👍']`), 'reaction toggled off');
  await ev(`actRoom='chat';actId='${mid1}';deleteMsg()`); ok(await ev(`findMsg('chat','${mid1}').deleted===true`), 'message deleted (tombstone)');
  await ev("back()");

  // --- group: create, invite, settings, leave ---
  await ev("openPage('creategroup')"); await wait(300); await click('#pg-creategroup .btn.primary'); ok(await ev("$('#fGName').classList.contains('bad')"), 'group name required');
  await page.type('#gName', 'QA Squad'); await ev("openInvite('create');ivToggle('p1');ivToggle('p3')"); await ev("inviteDone()"); ok(await ev("GD.members.length===2"), 'members picked for new group');
  await page.click('#pg-creategroup .btn.primary'); await wait(600); ok(await ev("GROUPS.some(g=>g.name==='QA Squad'&&g.members.length===2)"), 'group created with 2 members'); ok(await ev("curChat&&curChat.name==='QA Squad'"), 'opens the new group chat');
  await ev("openSettings();openInvite('add');ivToggle('p5');inviteDone()"); await wait(300); ok(await ev("curChat.members.includes('p5')"), 'member invited to existing group');
  await ev("leaveGroup()"); ok(await ev("GROUPS.some(g=>g.name==='QA Squad')"), 'leave needs 2nd tap'); await ev("leaveGroup()"); await wait(300); ok(await ev("!GROUPS.some(g=>g.name==='QA Squad')"), 'group left after confirm');

  // --- contacts add / edit / delete ---
  await ev("openAddContact(false)"); await page.type('#acName', 'Zed Zulu'); await click('#pg-addcontact .btn.primary'); ok(await ev("$('#fInfo').classList.contains('bad')"), 'contact info required');
  await page.type('#acInfo', 'zed@indie.id'); await click('#pg-addcontact .btn.primary'); await wait(600); ok(await ev("PEOPLE.some(p=>p.name==='Zed Zulu')"), 'contact saved');

  // --- search → jump to message ---
  await ev("openPage('search');$('#sqInput').value='creative brief';renderSearch()"); ok(await ev("$$('#sqBody .row').length>=1"), 'message search finds group message');

  // --- agent scope + orchestrator-created agent ---
  await ev("go('msg');openAgentChat('a2')"); await page.type('#agInput', 'order me a pizza'); await page.keyboard.press('Enter'); await wait(1500);
  ok(await ev("curAgent.messages.at(-1).t.includes('outside my workflow')"), 'agent refuses out-of-scope request');
  await page.type('#agInput', 'please summarize findings'); await page.keyboard.press('Enter'); await wait(1500); ok(await ev("curAgent.messages.at(-1).t.includes('part of my workflow')"), 'agent accepts in-scope request');
  await ev("go('msg');openOrch();$('#orInput').value='Create an agent to monitor my inbox';sendOrch()"); await wait(1600);
  ok(await ev("AGENTS.some(a=>a.name==='Monitor Inbox Agent'&&a.workflow.length>=3)"), 'Orchestrator creates agent with workflow'); ok(await ev("$('#orbWrap').style.display==='none'"), 'orb hidden once thread starts');

  // --- Personal Assistant ↔ connector parity ---
  await ev("go('msg');openAgentChat('a4')"); await page.type('#agInput', 'check my calendar'); await page.keyboard.press('Enter'); await wait(1500);
  ok(await ev("curAgent.messages.at(-1).t.includes('Connectors')"), 'assistant points to Connectors when not connected');
  await ev("toggleConnector('google_calendar')"); await page.type('#agInput', 'check my calendar again'); await page.keyboard.press('Enter'); await wait(1500);
  ok(await ev("curAgent.messages.at(-1).type==='card'"), 'assistant returns events card when connected');

  // --- Finance Agent ↔ Drive connector parity ---
  await ev("go('msg');openAgentChat('a3')"); await page.type('#agInput', 'read my invoices'); await page.keyboard.press('Enter'); await wait(1500);
  ok(await ev("curAgent.messages.at(-1).t.includes('Google Drive') && curAgent.messages.at(-1).t.includes('Connectors')"), 'finance agent points to Connectors when Drive is not connected');
  await ev("toggleConnector('google_drive')"); await page.type('#agInput', 'read invoices again'); await page.keyboard.press('Enter'); await wait(1500);
  ok(await ev("curAgent.messages.at(-1).type==='card' && curAgent.messages.at(-1).card.title==='Invoice files in your Drive'"), 'finance agent returns the invoice files card when Drive is connected');
  await page.type('#agInput', 'calculate the weekly cash flow'); await page.keyboard.press('Enter'); await wait(1500);
  ok(await ev("curAgent.messages.at(-1).t.includes('part of my workflow')"), 'other finance steps keep their normal behaviour');

  // --- flow: run → pause at approval → approve → complete; cancel path ---
  await ev("go('flow');openFlow('w1',true)"); await wait(6000); ok(await ev("FR.status==='waiting'"), 'flow pauses at approval node'); ok(await ev("$('#frBanner').style.display==='flex'"), 'approval banner visible');
  await ev("apprDecide(true)"); await wait(2600); ok(await ev("FR.status==='done'&&Object.values(FR.st).every(s=>s==='done')"), 'flow resumes and completes after approval');
  await ev("runFlow()"); await wait(1500); await ev("flowBtn()"); ok(await ev("FR.status==='cancelled'"), 'cancel stops a running flow'); await wait(1500); ok(await ev("FR.status==='cancelled'"), 'cancelled flow stays cancelled');
  await ev("openFlow('w1',true)"); await wait(6000); await ev("apprDecide(false)"); ok(await ev("FR.status==='cancelled'&&Object.values(FR.st).includes('skip')"), 'rejecting approval cancels and skips the rest');

  // --- builder: add node, connect, validate, condition ---
  await ev("openFlow('w3');openBuilder();bAddType('logic')"); ok(await ev("bW().nodes.some(n=>n.c==='logic')"), 'logic node added'); await ev("bSelect(bW().nodes.at(-1).id)"); ok(await ev("$('#bCondBtn').style.display!=='none'"), 'Condition button for logic node');
  await ev("bCondition();cdPick('probability');$('#cdBranch').value='Yes';$('#cdPct').value='70';cdSave()"); ok(await ev("bW().nodes.at(-1).cond.type==='probability'&&bW().nodes.at(-1).cond.percent===70"), 'condition saved');

  // --- share + vault ---
  await ev("openShare('o1');SH.to='p1';SH.inc.report=false;SH.inc.ai=false;doShare()"); ok(await ev("!OUTPUTS[0].shared"), 'share blocked when nothing selected');
  await ev("SH.inc.report=true;doShare()"); await wait(200); ok(await ev("OUTPUTS[0].shared&&chatById('p1').messages.at(-1).type==='output'"), 'share delivers only the output to recipient');
  ok(await ev("!JSON.stringify(chatById('p1').messages.at(-1)).includes('nodes')"), 'shared payload contains no workflow data');
  await ev("go('vault');vaultTab('notes');addNote();$('#ff_title').value='QA note';$('#ff_text').value='x';window._formOk()"); ok(await ev("NOTES[0].title==='QA note'"), 'note added to vault');

  // --- logout → welcome ---
  await ev("go('more');logout()"); await wait(400); ok(await ev("stack.includes('welcome')"), 'logout returns to welcome');
  console.log(`\n${pass} passed, ${fail} failed, ${errs.length} page errors`); if (errs.length) console.log(errs.join('\n'));
  await browser.close(); process.exit(fail || errs.length ? 1 : 0);
})();
