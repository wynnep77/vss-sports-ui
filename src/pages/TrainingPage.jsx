import { useState } from 'react';
import { Upload, BookOpen, Plus, CheckCircle, AlertCircle } from 'lucide-react';
import { addSportKnowledge, uploadTrainingVideo, getSupportedSports } from '../api/vssClient';

export default function TrainingPage() {
  const [activeTab, setActiveTab] = useState('knowledge'); // 'knowledge' or 'video'
  const [sport, setSport] = useState('');
  const [knowledge, setKnowledge] = useState('');
  const [trainingFile, setTrainingFile] = useState(null);
  const [status, setStatus] = useState('idle');
  const [message, setMessage] = useState('');
  const [supportedSports, setSupportedSports] = useState([
    'Football', 'Basketball', 'Tennis', 'Baseball', 'Soccer', 'Cricket'
  ]);

  const handleAddKnowledge = async () => {
    if (!sport || !knowledge) {
      setMessage('Please fill in all fields');
      setStatus('error');
      return;
    }

    setStatus('loading');
    try {
      await addSportKnowledge(sport, knowledge);
      setStatus('success');
      setMessage('Knowledge added successfully');
      setKnowledge('');
    } catch (error) {
      setStatus('error');
      setMessage('Failed to add knowledge');
    }
  };

  const handleUploadTrainingVideo = async () => {
    if (!sport || !trainingFile) {
      setMessage('Please select a sport and upload a video');
      setStatus('error');
      return;
    }

    setStatus('loading');
    try {
      await uploadTrainingVideo(trainingFile, sport);
      setStatus('success');
      setMessage('Training video uploaded successfully');
      setTrainingFile(null);
    } catch (error) {
      setStatus('error');
      setMessage('Failed to upload training video');
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Training</h1>
        <p className="text-gray-600 mt-1">Add sport-specific knowledge and training data</p>
      </div>

      {/* Tab Selection */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div className="flex space-x-4 mb-6">
          <button
            onClick={() => setActiveTab('knowledge')}
            className={`flex items-center space-x-2 px-4 py-2 rounded-lg transition-colors ${
              activeTab === 'knowledge' ? 'bg-primary-50 text-primary-700' : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <BookOpen className="h-5 w-5" />
            <span>Add Knowledge</span>
          </button>
          <button
            onClick={() => setActiveTab('video')}
            className={`flex items-center space-x-2 px-4 py-2 rounded-lg transition-colors ${
              activeTab === 'video' ? 'bg-primary-50 text-primary-700' : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <Upload className="h-5 w-5" />
            <span>Upload Training Video</span>
          </button>
        </div>

        {activeTab === 'knowledge' && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Sport
              </label>
              <select
                value={sport}
                onChange={(e) => setSport(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                <option value="">Select a sport</option>
                {supportedSports.map((s) => (
                  <option key={s} value={s}>{s}</option>
                ))}
                <option value="custom">Custom Sport...</option>
              </select>
            </div>

            {sport === 'custom' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Custom Sport Name
                </label>
                <input
                  type="text"
                  placeholder="Enter sport name"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                />
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Knowledge Description
              </label>
              <textarea
                value={knowledge}
                onChange={(e) => setKnowledge(e.target.value)}
                placeholder="Describe the rules, strategies, or specific aspects of this sport..."
                rows={6}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
            </div>

            <button
              onClick={handleAddKnowledge}
              disabled={status === 'loading'}
              className="w-full px-4 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
            >
              {status === 'loading' ? 'Adding...' : 'Add Knowledge'}
            </button>
          </div>
        )}

        {activeTab === 'video' && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Sport
              </label>
              <select
                value={sport}
                onChange={(e) => setSport(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                <option value="">Select a sport</option>
                {supportedSports.map((s) => (
                  <option key={s} value={s}>{s}</option>
                ))}
                <option value="custom">Custom Sport...</option>
              </select>
            </div>

            <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-primary-400 transition-colors">
              <Upload className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">Drag and drop a training video here, or click to select</p>
              <input
                type="file"
                accept="video/*"
                onChange={(e) => setTrainingFile(e.target.files[0])}
                className="hidden"
                id="training-upload"
              />
              <label
                htmlFor="training-upload"
                className="inline-block px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 cursor-pointer"
              >
                Select Video
              </label>
            </div>

            {trainingFile && (
              <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                <div>
                  <p className="font-medium text-gray-900">{trainingFile.name}</p>
                  <p className="text-sm text-gray-500">{(trainingFile.size / (1024 * 1024)).toFixed(2)} MB</p>
                </div>
                <button
                  onClick={() => setTrainingFile(null)}
                  className="text-red-600 hover:text-red-700"
                >
                  Remove
                </button>
              </div>
            )}

            <button
              onClick={handleUploadTrainingVideo}
              disabled={status === 'loading'}
              className="w-full px-4 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
            >
              {status === 'loading' ? 'Uploading...' : 'Upload Training Video'}
            </button>
          </div>
        )}

        {status === 'success' && (
          <div className="mt-4 flex items-center space-x-2 text-green-600">
            <CheckCircle className="h-5 w-5" />
            <span>{message}</span>
          </div>
        )}

        {status === 'error' && (
          <div className="mt-4 flex items-center space-x-2 text-red-600">
            <AlertCircle className="h-5 w-5" />
            <span>{message}</span>
          </div>
        )}
      </div>

      {/* Supported Sports Info */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Supported Sports</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
          {supportedSports.map((s) => (
            <div key={s} className="flex items-center space-x-2 p-3 bg-gray-50 rounded-lg">
              <Plus className="h-4 w-4 text-primary-600" />
              <span className="text-sm font-medium text-gray-700">{s}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
