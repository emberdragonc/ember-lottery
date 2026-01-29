import { NextResponse } from 'next/server';

const GITHUB_USERNAME = 'emberdragonc';

interface RepoData {
  name: string;
  description: string | null;
  html_url: string;
  stargazers_count: number;
  language: string | null;
  updated_at: string;
  pushed_at: string;
}

interface EventData {
  type: string;
  created_at: string;
  repo: { name: string };
  payload: {
    commits?: { message: string }[];
    action?: string;
    ref_type?: string;
  };
}

export async function GET() {
  try {
    // Fetch repos
    const reposRes = await fetch(
      `https://api.github.com/users/${GITHUB_USERNAME}/repos?sort=updated&per_page=100`,
      { next: { revalidate: 300 } } // Cache for 5 minutes
    );
    const repos: RepoData[] = await reposRes.json();

    // Fetch events (recent activity)
    const eventsRes = await fetch(
      `https://api.github.com/users/${GITHUB_USERNAME}/events?per_page=30`,
      { next: { revalidate: 60 } } // Cache for 1 minute
    );
    const events: EventData[] = await eventsRes.json();

    // Fetch user stats
    const userRes = await fetch(
      `https://api.github.com/users/${GITHUB_USERNAME}`,
      { next: { revalidate: 300 } }
    );
    const user = await userRes.json();

    // Calculate stats
    const totalStars = repos.reduce((sum: number, repo: RepoData) => sum + repo.stargazers_count, 0);
    const languages = repos.reduce((acc: Record<string, number>, repo: RepoData) => {
      if (repo.language) {
        acc[repo.language] = (acc[repo.language] || 0) + 1;
      }
      return acc;
    }, {});

    // Count push events (GitHub API often hides commit details)
    const pushEvents = events.filter((e: EventData) => e.type === 'PushEvent');
    // Each push event = at least 1 commit, use payload.size if available
    const commitCount = pushEvents.reduce((sum: number, e: EventData) => {
      const commits = e.payload.commits?.length || (e.payload as { size?: number }).size || 1;
      return sum + commits;
    }, 0);

    // Get activity by day (last 7 days)
    const activityByDay: Record<string, number> = {};
    const now = new Date();
    for (let i = 6; i >= 0; i--) {
      const date = new Date(now);
      date.setDate(date.getDate() - i);
      const key = date.toISOString().split('T')[0];
      activityByDay[key] = 0;
    }
    events.forEach((e: EventData) => {
      const date = e.created_at.split('T')[0];
      if (activityByDay[date] !== undefined) {
        activityByDay[date]++;
      }
    });

    // Format recent activity
    const recentActivity = events.slice(0, 10).map((e: EventData) => ({
      type: e.type,
      repo: e.repo.name.replace(`${GITHUB_USERNAME}/`, ''),
      date: e.created_at,
      message: e.type === 'PushEvent' 
        ? e.payload.commits?.[0]?.message?.slice(0, 50) 
        : e.payload.action || e.payload.ref_type || e.type,
    }));

    // Top repos
    const topRepos = repos
      .sort((a: RepoData, b: RepoData) => new Date(b.pushed_at).getTime() - new Date(a.pushed_at).getTime())
      .slice(0, 6)
      .map((r: RepoData) => ({
        name: r.name,
        description: r.description,
        url: r.html_url,
        stars: r.stargazers_count,
        language: r.language,
        updatedAt: r.updated_at,
      }));

    return NextResponse.json({
      stats: {
        repos: repos.length,
        stars: totalStars,
        commits: commitCount,
        followers: user.followers,
        following: user.following,
      },
      languages,
      activityByDay,
      recentActivity,
      topRepos,
      lastUpdated: new Date().toISOString(),
    });
  } catch (error) {
    console.error('GitHub API error:', error);
    return NextResponse.json(
      { error: 'Failed to fetch GitHub data' },
      { status: 500 }
    );
  }
}
