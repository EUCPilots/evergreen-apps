const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
    buildApps, findApps, rankIssues, knownLinks, commentBody, run
} = require('../.github/scripts/similar-issues.cjs');

const apps = buildApps([
    { id: 'GoogleChrome', Name: 'Google Chrome Enterprise' },
    { id: 'GoogleChromeDriver', Name: 'Google Chrome Driver' },
    { id: 'MozillaFirefox', Name: 'Mozilla Firefox' },
    { id: 'DockerDesktop', Name: 'Docker Desktop' },
    { id: 'ExampleDesktop', Name: 'Example Desktop' }
]);
const source = {
    number: 241,
    title: '[Bug]: Google Chrome Enterprise lists wrong version number for stable channel',
    body: '### What happened?\nThe stable MSI installer is older than reported.\n\n### Version\n26.10\n\n### Verbose output\nGet-EvergreenApp -Name GoogleChrome',
    labels: []
};
const earlier = {
    number: 69, title: '[Bug]: Chrome reports 143.x as stable, but the MSI is 142.*',
    body: '', state: 'closed', labels: [{ name: 'information' }]
};
const html = '<h1 id="known-issues">Known issues</h1><h3 id="googlechrome">GoogleChrome</h3>';

test('detects issue #241 and short product names in older reports', () => {
    assert.deepEqual(findApps(source, apps).map(app => app.id), ['GoogleChrome']);
    assert.deepEqual(findApps(earlier, apps).map(app => app.id), ['GoogleChrome']);
    assert.deepEqual(rankIssues(source, [earlier], apps), [earlier]);
    assert.deepEqual(knownLinks(findApps(source, apps), html),
        ['https://eucpilots.com/evergreen/issues#googlechrome']);
});

test('detects names in verbose output when the title does not identify an app', () => {
    assert.deepEqual(findApps({
        title: '[Bug]: Invalid response',
        body: 'Get-EvergreenApp -Name MozillaFirefox\nApps/Get-MozillaFirefox.ps1'
    }, apps).map(app => app.id), ['MozillaFirefox']);
});

test('uses word boundaries, avoids ambiguous short names, and prefers the title', () => {
    assert.deepEqual(findApps({ title: 'ChromeDriver failure', body: '' }, apps), []);
    assert.deepEqual(findApps({ title: 'Desktop failure', body: '' }, apps), []);
    assert.deepEqual(findApps({
        title: 'GoogleChrome failure', body: 'MozillaFirefox was used as a comparison'
    }, apps).map(app => app.id), ['GoogleChrome']);
});

test('excludes the source, newer reports, pull requests, new-app requests, and other apps', () => {
    const candidates = [
        source, { ...earlier, number: 242 },
        { ...earlier, number: 60, pull_request: {} },
        { ...earlier, number: 61, title: '[New app]: GoogleChrome' },
        { ...earlier, number: 62, title: '[New GitHub app]: GoogleChrome' },
        { ...earlier, number: 63, title: 'MozillaFirefox stable MSI older than reported' }
    ];
    assert.deepEqual(rankIssues(source, candidates, apps), []);
});

test('ranks known reports ahead of otherwise equal matches and limits results to five', () => {
    const candidates = Array.from({ length: 8 }, (_, index) => ({
        ...earlier, number: index + 1, labels: index === 0 ? [{ name: 'vendor issue' }] : []
    }));
    const matches = rankIssues(source, candidates, apps);
    assert.equal(matches.length, 5);
    assert.equal(matches[0].number, 1);
    assert.equal(matches[1].number, 8);
});

test('generic matching enforces both word overlap thresholds', () => {
    const issue = { number: 20, title: 'Proxy authentication certificate handshake failure', body: '' };
    const candidate = title => ({ number: 10, title, body: '', labels: [] });
    assert.equal(rankIssues(issue, [candidate('Proxy authentication certificate timeout')], apps).length, 1);
    assert.equal(rankIssues(issue, [candidate('Proxy authentication timeout')], apps).length, 0);
    assert.equal(rankIssues(issue, [
        candidate('Proxy authentication certificate unrelated extra words process response download update')
    ], apps).length, 1);
    const longIssue = { ...issue, title: `${issue.title} extra words process response download update` };
    assert.equal(rankIssues(longIssue, [
        candidate('Proxy authentication certificate unrelated several other differing tokens')
    ], apps).length, 0);
});

test('template checkboxes and verbose logs do not produce generic matches', () => {
    const body = '### What happened?\nSomething failed.\n\n### Have you reviewed the documentation?\nKnown issues troubleshooting documentation\n\n### Verbose output\nProxy authentication certificate handshake failure';
    const issue = { number: 20, title: '[Bug]: Problem', body };
    assert.deepEqual(rankIssues(issue, [
        { number: 10, title: '[Bug]: Unrelated', body }
    ], apps), []);
});

test('documentation links require an existing heading for the detected app', () => {
    assert.deepEqual(knownLinks(apps, html), ['https://eucpilots.com/evergreen/issues#googlechrome']);
    assert.deepEqual(knownLinks(apps, '<a href="#mozillafirefox">Navigation</a>'), []);
});

test('comments include states and known labels, not untrusted titles, and allow docs-only matches', () => {
    const body = commentBody([{ ...earlier, title: '@everyone [click](https://example.com)' }], []);
    assert.match(body, /#69 \(closed; information\)/);
    assert.doesNotMatch(body, /@everyone|example\.com/);
    assert.match(commentBody([], ['https://eucpilots.com/evergreen/issues#googlechrome']), /#googlechrome/);
    assert.equal(commentBody([], []), null);
});

function harness({ issue = source, candidates = [earlier], comments = [], labels = [], docs = html, status = 200 } = {}) {
    const calls = [];
    const api = name => async args => {
        calls.push({ name, args });
        return { data: name === 'get' ? issue : {} };
    };
    const issues = Object.fromEntries([
        'get', 'listForRepo', 'listComments', 'listLabelsForRepo', 'createLabel',
        'createComment', 'updateComment', 'deleteComment', 'addLabels', 'removeLabel'
    ].map(name => [name, api(name)]));
    const github = {
        rest: { issues },
        paginate: async method => {
            if (method === issues.listForRepo) return candidates;
            if (method === issues.listComments) return comments;
            if (method === issues.listLabelsForRepo) return labels;
            throw new Error('Unexpected paginated request');
        }
    };
    const summary = {
        addHeading() { return this; },
        addRaw() { return this; },
        async write() {}
    };
    return {
        calls,
        args: {
            github, context: { repo: { owner: 'EUCPilots', repo: 'evergreen-apps' } },
            core: { info() {}, summary },
            fetchImpl: async url => {
                assert.equal(url, 'https://eucpilots.com/evergreen/issues');
                return { ok: status === 200, status, text: async () => docs };
            },
            env: { ISSUE_NUMBER: String(issue.number), DRY_RUN: 'false' }
        }
    };
}

test('creates a comment and label without changing issue status or classifications', async () => {
    const { args, calls } = harness();
    await run(args);
    assert.deepEqual(calls.map(call => call.name), ['get', 'createLabel', 'createComment', 'addLabels']);
    assert.deepEqual(calls.at(-1).args.labels, ['similar issues']);
    assert.match(calls.find(call => call.name === 'createComment').args.body, /#69/);
});

test('dry runs perform no writes', async () => {
    const { args, calls } = harness();
    args.env.DRY_RUN = 'true';
    await run(args);
    assert.deepEqual(calls.map(call => call.name), ['get']);
});

test('updates only its own marked bot comment and does not create duplicates', async () => {
    const comments = [
        { id: 1, user: { login: 'someone' }, body: '<!-- evergreen-similar-issues -->\nSpoof' },
        { id: 2, user: { login: 'github-actions[bot]' }, body: '<!-- evergreen-similar-issues -->\nOld' }
    ];
    const { args, calls } = harness({ comments, labels: [{ name: 'similar issues' }] });
    await run(args);
    assert.deepEqual(calls.map(call => call.name), ['get', 'updateComment', 'addLabels']);
    assert.equal(calls.find(call => call.name === 'updateComment').args.comment_id, 2);
    const body = calls.find(call => call.name === 'updateComment').args.body;
    const repeat = harness({ comments: [{ ...comments[1], body }], labels: [{ name: 'similar issues' }] });
    await run(repeat.args);
    assert.deepEqual(repeat.calls.map(call => call.name), ['get', 'addLabels']);
});

test('removes stale suggestions and only the workflow label when no matches remain', async () => {
    const { args, calls } = harness({
        issue: { number: 241, title: 'Unrelated', body: '', labels: [{ name: 'similar issues' }, { name: 'bug' }] },
        candidates: [],
        comments: [{ id: 2, user: { login: 'github-actions[bot]' }, body: '<!-- evergreen-similar-issues -->\nOld' }]
    });
    await run(args);
    assert.deepEqual(calls.map(call => call.name), ['get', 'deleteComment', 'removeLabel']);
    assert.equal(calls.at(-1).args.name, 'similar issues');
});

test('does not post empty suggestions', async () => {
    const { args, calls } = harness({
        issue: { number: 241, title: 'Unrelated', body: '', labels: [] }, candidates: []
    });
    await run(args);
    assert.deepEqual(calls.map(call => call.name), ['get']);
});

test('invalid inputs and pull requests fail explicitly', async () => {
    for (const value of ['0', '-1', '241; echo bad', '9007199254740992']) {
        const { args } = harness();
        args.env.ISSUE_NUMBER = value;
        await assert.rejects(run(args), /positive safe integer/);
    }
    const { args } = harness({ issue: { ...source, pull_request: {} } });
    await assert.rejects(run(args), /pull request/);
});

test('documentation failures fail before changing comments or labels', async () => {
    for (const options of [{ status: 503 }, { docs: '<html>Unexpected page</html>' }]) {
        const { args, calls } = harness(options);
        await assert.rejects(run(args), /documentation/);
        assert.deepEqual(calls.map(call => call.name), ['get']);
    }
});

test('handles only the expected concurrent label-creation conflict', async () => {
    const concurrent = harness();
    concurrent.args.github.rest.issues.createLabel = async () => {
        throw { status: 422, response: { data: { errors: [{ code: 'already_exists' }] } } };
    };
    await run(concurrent.args);
    assert.ok(concurrent.calls.some(call => call.name === 'createComment'));
    const forbidden = harness();
    forbidden.args.github.rest.issues.createLabel = async () => { throw new Error('Forbidden'); };
    await assert.rejects(run(forbidden.args), /Forbidden/);
    assert.ok(!forbidden.calls.some(call => call.name === 'createComment'));
});
