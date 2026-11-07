const fs = require('node:fs');
const path = require('node:path');

const marker = '<!-- evergreen-similar-issues -->';
const label = 'similar issues';
const docsUrl = 'https://eucpilots.com/evergreen/issues';
const knownLabels = new Set(['information', 'vendor issue']);
const stopWords = new Set(
    'a an and are as at be bug by can does evergreen for from get has have i in is it latest new not of on or powershell report the this to version versions was when windows with wrong'.split(' ')
);

function normalize(text) {
    return text.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

function words(text) {
    return new Set(normalize(text).split(/\s+/).filter(word =>
        word.length > 2 && !stopWords.has(word) && !/^\d+$/.test(word)));
}

function description(issue) {
    const body = issue.body || '';
    const field = body.match(/### What happened\?\s*\n([\s\S]*?)(?=\n### |$)/i);
    return `${issue.title}\n${field ? field[1] : body.split(/\n### /)[0]}`
        .replace(/```[\s\S]*?(?:```|$)/g, '');
}

function buildApps(manifests) {
    const apps = manifests.map(({ id, Name }) => {
        const spaced = id.replace(/([a-z0-9])([A-Z])/g, '$1 $2');
        return { id, aliases: new Set([id, Name, spaced].filter(Boolean).map(normalize)) };
    });
    const shortNames = new Map();
    for (const app of apps) {
        const name = normalize(app.id.replace(/([a-z0-9])([A-Z])/g, '$1 $2')).split(' ').at(-1);
        if (name.length >= 4) {
            if (!shortNames.has(name)) shortNames.set(name, []);
            shortNames.get(name).push(app);
        }
    }
    for (const [name, matches] of shortNames) {
        if (matches.length === 1) matches[0].aliases.add(name);
    }
    return apps;
}

function findApps(issue, apps) {
    const match = text => {
        const normalized = ` ${normalize(text)} `;
        return apps.filter(app => [...app.aliases].some(alias => normalized.includes(` ${alias} `)));
    };
    const titleMatches = match(issue.title);
    return titleMatches.length ? titleMatches : match(issue.body || '');
}

function rankIssues(issue, candidates, apps) {
    const sourceApps = new Set(findApps(issue, apps).map(app => app.id));
    const sourceWords = words(description(issue));
    return candidates.filter(candidate =>
        !candidate.pull_request && candidate.number < issue.number &&
        !/^\[?new[ /-]?(?:github[ -])?app/i.test(candidate.title)
    ).map(candidate => {
        const sameApp = findApps(candidate, apps).some(app => sourceApps.has(app.id));
        if (sourceApps.size && !sameApp) return null;
        const candidateWords = words(description(candidate));
        const overlap = [...sourceWords].filter(word => candidateWords.has(word)).length;
        const similarity = overlap / Math.max(1, Math.min(sourceWords.size, candidateWords.size));
        if (!sameApp && (overlap < 3 || similarity < 0.5)) return null;
        const known = (candidate.labels || []).some(item => knownLabels.has(item.name));
        return { issue: candidate, score: overlap + similarity + (known ? 2 : 0) };
    }).filter(Boolean).sort((a, b) => b.score - a.score || b.issue.number - a.issue.number)
        .slice(0, 5).map(result => result.issue);
}

function knownLinks(apps, html) {
    const anchors = new Set([...html.matchAll(/<h[23]\b[^>]*\bid=["']([^"']+)["']/gi)]
        .map(match => match[1]));
    return apps.filter(app => anchors.has(app.id.toLowerCase()))
        .map(app => `${docsUrl}#${app.id.toLowerCase()}`);
}

function commentBody(matches, links) {
    if (!matches.length && !links.length) return null;
    const lines = [marker, '### Possibly related issues', ''];
    if (matches.length) {
        lines.push('Earlier reports that may help (including closed issues):', '');
        for (const issue of matches) {
            const labels = (issue.labels || []).map(item => item.name).filter(name => knownLabels.has(name));
            lines.push(`- #${issue.number} (${issue.state}${labels.length ? `; ${labels.join(', ')}` : ''})`);
        }
        lines.push('');
    }
    if (links.length) {
        lines.push('Known-issue documentation for the detected application:', '',
            ...links.map(link => `- ${link}`), '');
    }
    lines.push('These are suggestions, not a duplicate determination. Please compare the symptoms and any documented workarounds. No issue status or classification labels have been changed.');
    return lines.join('\n');
}

async function run({ github, context, core, fetchImpl = fetch, env = process.env }) {
    if (!/^[1-9]\d*$/.test(env.ISSUE_NUMBER || '') || !Number.isSafeInteger(Number(env.ISSUE_NUMBER))) {
        throw new Error('ISSUE_NUMBER must be a positive safe integer.');
    }
    const repo = context.repo;
    const issue_number = Number(env.ISSUE_NUMBER);
    const { data: issue } = await github.rest.issues.get({ ...repo, issue_number });
    if (issue.pull_request) throw new Error('The supplied number is a pull request, not an issue.');
    const apps = buildApps(fs.readdirSync('Manifests').filter(file => file.endsWith('.json')).map(file => ({
        ...JSON.parse(fs.readFileSync(path.join('Manifests', file), 'utf8').replace(/^\uFEFF/, '')),
        id: path.basename(file, '.json')
    })));
    const detectedApps = findApps(issue, apps);
    const candidates = await github.paginate(github.rest.issues.listForRepo, {
        ...repo, state: 'all', per_page: 100
    });
    const matches = rankIssues(issue, candidates, apps);
    let links = [];
    if (detectedApps.length) {
        const response = await fetchImpl(docsUrl, { signal: AbortSignal.timeout(30000) });
        if (!response.ok) throw new Error(`Known-issues documentation request failed: HTTP ${response.status}`);
        const html = await response.text();
        if (!/<h1\b[^>]*\bid=["']known-issues["']/i.test(html)) {
            throw new Error('Known-issues documentation no longer has the expected page structure.');
        }
        links = knownLinks(detectedApps, html);
    }
    const body = commentBody(matches, links);
    core.info(body || 'No related reports or application-specific known issues found.');
    await core.summary.addHeading(`Similar issues for #${issue_number}`)
        .addRaw(body || 'No matches.', true).write();
    if (env.DRY_RUN === 'true') return;

    const comments = await github.paginate(github.rest.issues.listComments, {
        ...repo, issue_number, per_page: 100
    });
    const previous = comments.find(comment =>
        comment.user?.login === 'github-actions[bot]' && comment.body?.startsWith(marker));
    if (!body) {
        if (previous) await github.rest.issues.deleteComment({ ...repo, comment_id: previous.id });
        if ((issue.labels || []).some(item => item.name === label)) {
            await github.rest.issues.removeLabel({ ...repo, issue_number, name: label });
        }
        return;
    }

    const labels = await github.paginate(github.rest.issues.listLabelsForRepo, { ...repo, per_page: 100 });
    if (!labels.some(item => item.name === label)) {
        try {
            await github.rest.issues.createLabel({
                ...repo, name: label, color: 'c5def5',
                description: 'Automation found potentially related reports or known-issue documentation'
            });
        } catch (error) {
            if (error.status !== 422 || !error.response?.data?.errors?.some(item => item.code === 'already_exists')) {
                throw error;
            }
            core.info('Another run already created the similar issues label.');
        }
    }
    if (previous) {
        if (previous.body !== body) {
            await github.rest.issues.updateComment({ ...repo, comment_id: previous.id, body });
        }
    } else {
        await github.rest.issues.createComment({ ...repo, issue_number, body });
    }
    await github.rest.issues.addLabels({ ...repo, issue_number, labels: [label] });
}

module.exports = { buildApps, findApps, rankIssues, knownLinks, commentBody, run };
