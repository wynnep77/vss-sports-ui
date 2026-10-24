import { useState, useEffect } from 'react';
import { Video, Clock, CheckCircle, AlertCircle, TrendingUp, GraduationCap, MessageSquare } from 'lucide-react';
import { checkHealth, getAnalysisResults } from '../api/vssClient';

export default function DashboardPage() {
  const [healthStatus, setHealthStatus] = useState('checking');
  const [stats, setStats] = useState({
    totalVideos: 0,
    processing: 0,
    completed: 0,
    failed: 0,
  });
  const [recentAnalyses, setRecentAnalyses] = useState([]);

  useEffect(() => {
    checkSystemHealth();
    loadStats();
  }, []);

  const checkSystemHealth = async () => {
    try {
      await checkHealth();
      setHealthStatus('healthy');
    } catch (error) {
      setHealthStatus('unhealthy');
    }
  };

  const loadStats = async () => {
    // Mock data for now - would come from API
    setStats({
      totalVideos: 12,
      processing: 2,
      completed: 9,
      failed: 1,
    });
    setRecentAnalyses([
      { id: 1, name: 'Football Match Analysis', status: 'completed', date: '2024-10-20' },
      { id: 2, name: 'Basketball Game Highlights', status: 'processing', date: '2024-10-21' },
      { id: 3, name: 'Tennis Match Review', status: 'completed', date: '2024-10-19' },
    ]);
  };

  const statCards = [
    { label: 'Total Videos', value: stats.totalVideos, icon: Video, color: 'blue' },
    { label: 'Processing', value: stats.processing, icon: Clock, color: 'yellow' },
    { label: 'Completed', value: stats.completed, icon: CheckCircle, color: 'green' },
    { label: 'Failed', value: stats.failed, icon: AlertCircle, color: 'red' },
  ];

  const colorClasses = {
    blue: 'bg-blue-50 text-blue-700 border-blue-200',
    yellow: 'bg-yellow-50 text-yellow-700 border-yellow-200',
    green: 'bg-green-50 text-green-700 border-green-200',
    red: 'bg-red-50 text-red-700 border-red-200',
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-600 mt-1">Overview of your sports video analysis</p>
      </div>

      {/* Health Status */}
      <div className={`p-4 rounded-lg border ${
        healthStatus === 'healthy' ? 'bg-green-50 border-green-200' :
        healthStatus === 'unhealthy' ? 'bg-red-50 border-red-200' :
        'bg-gray-50 border-gray-200'
      }`}>
        <div className="flex items-center space-x-2">
          {healthStatus === 'healthy' && <CheckCircle className="h-5 w-5 text-green-600" />}
          {healthStatus === 'unhealthy' && <AlertCircle className="h-5 w-5 text-red-600" />}
          {healthStatus === 'checking' && <Clock className="h-5 w-5 text-gray-600" />}
          <span className="font-medium">
            {healthStatus === 'healthy' ? 'VSS Backend is Healthy' :
             healthStatus === 'unhealthy' ? 'VSS Backend is Unhealthy' :
             'Checking VSS Backend...'}
          </span>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((stat) => {
          const Icon = stat.icon;
          return (
            <div key={stat.label} className={`p-6 rounded-lg border ${colorClasses[stat.color]}`}>
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium opacity-80">{stat.label}</p>
                  <p className="text-3xl font-bold mt-2">{stat.value}</p>
                </div>
                <Icon className="h-8 w-8 opacity-60" />
              </div>
            </div>
          );
        })}
      </div>

      {/* Recent Analyses */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Recent Analyses</h2>
        </div>
        <div className="divide-y divide-gray-200">
          {recentAnalyses.map((analysis) => (
            <div key={analysis.id} className="p-4 flex items-center justify-between hover:bg-gray-50">
              <div className="flex items-center space-x-4">
                <Video className="h-5 w-5 text-gray-400" />
                <div>
                  <p className="font-medium text-gray-900">{analysis.name}</p>
                  <p className="text-sm text-gray-500">{analysis.date}</p>
                </div>
              </div>
              <span className={`px-3 py-1 rounded-full text-xs font-medium ${
                analysis.status === 'completed' ? 'bg-green-100 text-green-700' :
                analysis.status === 'processing' ? 'bg-yellow-100 text-yellow-700' :
                'bg-red-100 text-red-700'
              }`}>
                {analysis.status}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-gradient-to-br from-primary-500 to-primary-600 p-6 rounded-lg text-white">
          <TrendingUp className="h-8 w-8 mb-2" />
          <h3 className="font-semibold text-lg">Analyze New Video</h3>
          <p className="text-sm opacity-90 mt-1">Upload or link a video for analysis</p>
        </div>
        <div className="bg-gradient-to-br from-purple-500 to-purple-600 p-6 rounded-lg text-white">
          <GraduationCap className="h-8 w-8 mb-2" />
          <h3 className="font-semibold text-lg">Train Model</h3>
          <p className="text-sm opacity-90 mt-1">Add sport-specific knowledge</p>
        </div>
        <div className="bg-gradient-to-br from-green-500 to-green-600 p-6 rounded-lg text-white">
          <MessageSquare className="h-8 w-8 mb-2" />
          <h3 className="font-semibold text-lg">Chat with AI</h3>
          <p className="text-sm opacity-90 mt-1">Query video insights</p>
        </div>
      </div>
    </div>
  );
}
