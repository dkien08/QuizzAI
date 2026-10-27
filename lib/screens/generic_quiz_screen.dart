import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ai_service.dart';

class GenericQuizScreen extends StatefulWidget {
  final String? examId;
  final String? examSessionId;
  final String examTitle;
  final int durationMinutes;
  final bool isPracticeMode;
  final List<Map<String, dynamic>> questions;

  const GenericQuizScreen({
    Key? key,
    this.examId,
    this.examSessionId,
    required this.examTitle,
    required this.durationMinutes,
    this.isPracticeMode = false,
    required this.questions,
  }) : super(key: key);

  @override
  State<GenericQuizScreen> createState() => _GenericQuizScreenState();
}

class _GenericQuizScreenState extends State<GenericQuizScreen> {
  int _currentQuestionIndex = 0;
  bool _autoAdvance = true;
  bool _isExplaining = false;
  bool _isSubmitting = false;
  bool _isExitDialogOpen = false;
  bool _showOfficialResult = false;
  Timer? _examTimer;
  int _remainingSeconds = 0;
  final Map<int, int> _selectedAnswers = {};
  final Map<int, bool> _answerCorrect = {};
  final Map<int, List<String>> _questionOptions = {};
  final Map<int, int> _questionCorrectAnswerIndex = {};
  final Map<int, int> _wrongAttempts = {};
  final Set<int> _firstTryCorrect = {};
  late final List<int> _practiceQueue;

  @override
  void initState() {
    super.initState();
    _practiceQueue = List<int>.generate(
      widget.questions.length,
      (index) => index,
    );
    for (var index = 0; index < widget.questions.length; index++) {
      final question = widget.questions[index];
      final options = (question['options'] as List<dynamic>? ?? const [])
          .map((option) => option.toString().trim())
          .toList();
      final rawCorrectIndex = question['correctAnswerIndex'];
      var correctIndex = rawCorrectIndex is num
          ? rawCorrectIndex.toInt()
          : int.tryParse(rawCorrectIndex?.toString() ?? '') ?? -1;
      final correctAnswerText = question['correctAnswer']?.toString().trim();
      if (correctAnswerText?.isNotEmpty == true) {
        final textIndex = options.indexOf(correctAnswerText!);
        if (textIndex >= 0) correctIndex = textIndex;
      }
      _questionOptions[index] = options;
      _questionCorrectAnswerIndex[index] = correctIndex;
    }
    if (!widget.isPracticeMode && widget.durationMinutes > 0) {
      _remainingSeconds = widget.durationMinutes * 60;
      _examTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _showOfficialResult || _isSubmitting) return;
        if (_remainingSeconds <= 1) {
          _examTimer?.cancel();
          _saveOfficialSubmission(status: 'timeout');
          return;
        }
        setState(() => _remainingSeconds--);
      });
    }
  }

  Map<String, dynamic> get _currentQuestion =>
      widget.questions[_currentQuestionIndex];

  List<String> get _options =>
      _questionOptions[_currentQuestionIndex] ?? const <String>[];

  int get _correctAnswerIndex =>
      _questionCorrectAnswerIndex[_currentQuestionIndex] ?? 0;

  bool get _isComplete => widget.isPracticeMode && _practiceQueue.isEmpty;

  String _formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.examTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Đề thi "${widget.examTitle}" chưa có câu hỏi.',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (!widget.isPracticeMode && _showOfficialResult) {
      return _buildOfficialResult(context);
    }

    if (_isComplete) {
      return _buildCompletionScreen(context);
    }

    final selectedAnswer = _selectedAnswers[_currentQuestionIndex];
    final answeredCorrectly = _answerCorrect[_currentQuestionIndex];
    final progress = widget.isPracticeMode
        ? (widget.questions.length - _practiceQueue.length) /
              widget.questions.length
        : _selectedAnswers.length / widget.questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.examTitle),
          actions: [
            if (!widget.isPracticeMode && widget.durationMinutes > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    '⏱ ${_formatRemainingTime()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _remainingSeconds <= 60
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                ),
              ),
            TextButton(
              onPressed: _isSubmitting ? null : _confirmExit,
              child: Text(widget.isPracticeMode ? 'Kết thúc' : 'Lưu và thoát'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.isPracticeMode
                              ? 'Đã hoàn thành ${widget.questions.length - _practiceQueue.length}/${widget.questions.length} câu'
                              : 'Đã trả lời ${_selectedAnswers.length}/${widget.questions.length} câu',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Câu ${_currentQuestionIndex + 1}/${widget.questions.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: Colors.blue.shade50,
                    ),
                    if (!widget.isPracticeMode) ...[
                      const SizedBox(height: 12),
                      _buildQuestionProgressGrid(),
                    ],
                  ],
                ),
              ),
              if (widget.isPracticeMode)
                SwitchListTile.adaptive(
                  dense: true,
                  title: const Text('Tự động chuyển câu'),
                  subtitle: const Text('Tắt nếu muốn xem lại đáp án trước'),
                  value: _autoAdvance,
                  onChanged: (value) => setState(() => _autoAdvance = value),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentQuestion['content']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...List.generate(_options.length, (index) {
                        final isSelected = selectedAnswer == index;
                        final isCorrectOption = _correctAnswerIndex == index;
                        final showResult =
                            widget.isPracticeMode &&
                            answeredCorrectly != null &&
                            (isSelected || isCorrectOption);
                        final resultColor = showResult
                            ? isCorrectOption
                                  ? Colors.green
                                  : Colors.red
                            : isSelected
                            ? Colors.blue
                            : Colors.grey.shade300;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            tileColor: showResult
                                ? (isCorrectOption
                                      ? Colors.green.shade50
                                      : Colors.red.shade50)
                                : isSelected
                                ? Colors.blue.shade50
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: resultColor),
                            ),
                            title: Text(_options[index]),
                            trailing: showResult
                                ? Icon(
                                    isCorrectOption
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: resultColor,
                                  )
                                : isSelected
                                ? const Icon(
                                    Icons.radio_button_checked,
                                    color: Colors.blue,
                                  )
                                : const Icon(
                                    Icons.radio_button_off,
                                    color: Colors.grey,
                                  ),
                            onTap: () => _selectAnswer(index),
                          ),
                        );
                      }),
                      if (widget.isPracticeMode && answeredCorrectly != null)
                        _buildFeedback(answeredCorrectly),
                      const SizedBox(height: 12),
                      if (widget.isPracticeMode)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isExplaining ? null : _explainWithAi,
                            icon: _isExplaining
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: const Text('Gọi AI giải thích đáp án'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _buildNavigationBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionScreen(BuildContext context) {
    final correctOnFirstTry = _firstTryCorrect.length;
    final needsRetry = _wrongAttempts.keys.toList()..sort();
    final accuracy = widget.questions.isEmpty
        ? 0.0
        : correctOnFirstTry / widget.questions.length * 100;

    return Scaffold(
      appBar: AppBar(title: Text(widget.examTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.celebration, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Bạn đã hoàn thành bài luyện tập!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildSummaryMetric(
                  'Đúng ngay',
                  '$correctOnFirstTry/${widget.questions.length}',
                  Colors.green,
                ),
                const SizedBox(width: 10),
                _buildSummaryMetric(
                  'Cần làm lại',
                  '${needsRetry.length}',
                  Colors.orange,
                ),
                const SizedBox(width: 10),
                _buildSummaryMetric(
                  'Tỷ lệ đúng',
                  '${accuracy.toStringAsFixed(1)}%',
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSummarySection(
              title: 'Câu đúng ngay lần đầu',
              icon: Icons.check_circle,
              color: Colors.green,
              questionIndexes: _firstTryCorrect.toList()..sort(),
              emptyText: 'Không có câu nào đúng ngay lần đầu.',
            ),
            const SizedBox(height: 16),
            _buildSummarySection(
              title: 'Câu cần làm lại',
              icon: Icons.replay,
              color: Colors.orange,
              questionIndexes: needsRetry,
              emptyText: 'Không có câu nào cần làm lại.',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _finishPractice,
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<int> questionIndexes,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        if (questionIndexes.isEmpty)
          Text(emptyText, style: const TextStyle(color: Colors.grey))
        else
          ...questionIndexes.map(
            (index) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: color.withOpacity(0.12),
                child: Text('${index + 1}', style: TextStyle(color: color)),
              ),
              title: Text(
                widget.questions[index]['content']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeedback(bool isCorrect) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isCorrect
            ? 'Chính xác! Câu này đã được hoàn thành.'
            : 'Chưa đúng. Câu này sẽ được lặp lại, hãy thử lại nhé.',
        style: TextStyle(
          color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    final queuePosition = _practiceQueue.indexOf(_currentQuestionIndex);
    final canGoPrevious = widget.isPracticeMode
        ? queuePosition > 0
        : _currentQuestionIndex > 0;
    final isLastQuestion = widget.isPracticeMode
        ? _practiceQueue.length <= 1
        : _currentQuestionIndex == widget.questions.length - 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: canGoPrevious ? _goToPrevious : null,
            child: const Text('Câu trước'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: widget.isPracticeMode
                  ? (_isComplete ? _finishPractice : _goToNext)
                  : (isLastQuestion ? _confirmSubmitExam : _goToNext),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isComplete ? Colors.green : Colors.blue,
              ),
              child: Text(
                widget.isPracticeMode
                    ? (_isComplete
                          ? 'Hoàn thành'
                          : isLastQuestion
                          ? 'Câu đầu / tiếp tục'
                          : 'Câu tiếp theo')
                    : (isLastQuestion ? 'Nộp bài' : 'Câu tiếp theo'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionProgressGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(widget.questions.length, (index) {
        final isAnswered = _selectedAnswers.containsKey(index);
        final isCurrent = _currentQuestionIndex == index;
        return SizedBox(
          width: 42,
          height: 38,
          child: OutlinedButton(
            onPressed: () => setState(() => _currentQuestionIndex = index),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: isAnswered ? Colors.green : Colors.white,
              foregroundColor: isAnswered ? Colors.white : Colors.black87,
              side: BorderSide(
                color: isCurrent ? Colors.blue.shade700 : Colors.grey.shade300,
                width: isCurrent ? 2 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('${index + 1}'),
          ),
        );
      }),
    );
  }

  Future<void> _selectAnswer(int answerIndex) async {
    if (widget.isPracticeMode &&
        _answerCorrect[_currentQuestionIndex] == true) {
      return;
    }

    final questionIndex = _currentQuestionIndex;
    final isCorrect = answerIndex == _correctAnswerIndex;
    setState(() {
      _selectedAnswers[questionIndex] = answerIndex;
      _answerCorrect[questionIndex] = isCorrect;
      if (widget.isPracticeMode && isCorrect) {
        _practiceQueue.remove(questionIndex);
        if (!_wrongAttempts.containsKey(questionIndex)) {
          _firstTryCorrect.add(questionIndex);
        }
      } else if (widget.isPracticeMode) {
        _wrongAttempts[questionIndex] =
            (_wrongAttempts[questionIndex] ?? 0) + 1;
      }
    });

    if (widget.isPracticeMode && isCorrect && _practiceQueue.isEmpty) {
      await _recordPracticeStreak();
    }

    if (!widget.isPracticeMode || !_autoAdvance) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted ||
        _currentQuestionIndex != questionIndex ||
        _answerCorrect[questionIndex] != isCorrect) {
      return;
    }
    if (!_isComplete) {
      _goToNext();
    }
  }

  void _goToNext() {
    if (widget.isPracticeMode && _practiceQueue.isEmpty) {
      return;
    }

    final shouldShuffle =
        widget.isPracticeMode && _answerCorrect[_currentQuestionIndex] == false;
    _clearCurrentAnswer();
    if (shouldShuffle) {
      _shuffleQuestionAnswers(_currentQuestionIndex);
    }
    setState(() {
      if (widget.isPracticeMode) {
        final currentPosition = _practiceQueue.indexOf(_currentQuestionIndex);
        final nextPosition = currentPosition < 0
            ? 0
            : (currentPosition + 1) % _practiceQueue.length;
        _currentQuestionIndex = _practiceQueue[nextPosition];
      } else {
        _currentQuestionIndex++;
      }
    });
  }

  void _goToPrevious() {
    final shouldShuffle =
        widget.isPracticeMode && _answerCorrect[_currentQuestionIndex] == false;
    _clearCurrentAnswer();
    if (shouldShuffle) {
      _shuffleQuestionAnswers(_currentQuestionIndex);
    }
    setState(() {
      if (widget.isPracticeMode) {
        final currentPosition = _practiceQueue.indexOf(_currentQuestionIndex);
        _currentQuestionIndex = _practiceQueue[currentPosition - 1];
      } else {
        _currentQuestionIndex--;
      }
    });
  }

  void _clearCurrentAnswer() {
    if (!widget.isPracticeMode) return;
    _selectedAnswers.remove(_currentQuestionIndex);
    _answerCorrect.remove(_currentQuestionIndex);
  }

  void _shuffleQuestionAnswers(int questionIndex) {
    final options = _questionOptions[questionIndex];
    final oldCorrectIndex = _questionCorrectAnswerIndex[questionIndex];
    if (options == null || oldCorrectIndex == null || options.length < 2) {
      return;
    }

    final safeCorrectIndex = oldCorrectIndex.clamp(0, options.length - 1);
    final correctAnswer = options[safeCorrectIndex];
    final shuffled = List<String>.from(options)..shuffle(math.Random());
    var orderUnchanged = true;
    for (var index = 0; index < options.length; index++) {
      if (shuffled[index] != options[index]) {
        orderUnchanged = false;
        break;
      }
    }
    if (orderUnchanged) {
      final first = shuffled[0];
      shuffled[0] = shuffled[1];
      shuffled[1] = first;
    }
    _questionOptions[questionIndex] = shuffled;
    _questionCorrectAnswerIndex[questionIndex] = shuffled.indexOf(
      correctAnswer,
    );
  }

  Future<void> _explainWithAi() async {
    final correctAnswer =
        _correctAnswerIndex >= 0 && _correctAnswerIndex < _options.length
        ? _options[_correctAnswerIndex].trim()
        : '';
    if (correctAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Câu hỏi này chưa có đáp án đúng hợp lệ.'),
        ),
      );
      return;
    }

    setState(() => _isExplaining = true);
    final explanation = await AIService.explainQuestion(
      questionContent: _currentQuestion['content']?.toString() ?? '',
      options: _options,
      correctAnswer: correctAnswer,
    );
    if (!mounted) return;
    setState(() => _isExplaining = false);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI giải thích'),
        content: SingleChildScrollView(child: Text(explanation)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishPractice() async {
    if (!mounted) return;
    await _recordPracticeStreak();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bạn đã hoàn thành bài luyện tập!')),
    );
    Navigator.pop(context);
  }

  Widget _buildOfficialResult(BuildContext context) {
    final correctCount = _selectedAnswers.entries
        .where((entry) => _questionCorrectAnswerIndex[entry.key] == entry.value)
        .length;
    final percentage = widget.questions.isEmpty
        ? 0.0
        : correctCount / widget.questions.length * 100;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả bài thi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.assignment_turned_in,
              size: 68,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            const Text(
              'Bài thi đã được nộp',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text('$correctCount/${widget.questions.length} câu đúng'),
                    const SizedBox(height: 8),
                    Text(
                      'Câu chưa trả lời hoặc trả lời sai: '
                      '${widget.questions.length - correctCount}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSubmitExam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nộp bài?'),
        content: const Text(
          'Sau khi nộp, bạn không thể mở lại hoặc thi lại bài này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục làm'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _saveOfficialSubmission(status: 'submitted');
    }
  }

  Future<void> _saveOfficialSubmission({required String status}) async {
    if (_isSubmitting || widget.examId == null) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final answers = <String, dynamic>{};
      for (final entry in _selectedAnswers.entries) {
        answers['${entry.key}'] = entry.value;
      }
      final correctCount = _selectedAnswers.entries
          .where(
            (entry) => _questionCorrectAnswerIndex[entry.key] == entry.value,
          )
          .length;
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser!;
      final userSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .get();
      final userData = userSnapshot.data() ?? const <String, dynamic>{};
      final totalQuestions = widget.questions.length;
      final score = totalQuestions == 0
          ? 0.0
          : correctCount / totalQuestions * 10;
      final submission = firestore.collection('exam_submissions').doc();
      final batch = firestore.batch();
      batch.set(submission, {
        'examId': widget.examId,
        'userId': userId,
        'userName': userData['fullName']?.toString() ?? '',
        'userEmail': user.email ?? '',
        'answers': answers,
        'correctCount': correctCount,
        'totalQuestions': totalQuestions,
        'score': score,
        'status': status,
        'submittedAt': FieldValue.serverTimestamp(),
      });
      if (widget.examSessionId != null) {
        batch.update(
          firestore.collection('exam_sessions').doc(widget.examSessionId),
          {'status': status, 'finishedAt': FieldValue.serverTimestamp()},
        );
      }
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _showOfficialResult = status != 'abandoned';
      });
      if (status == 'abandoned') {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lưu bài thi: $error')));
    }
  }

  Future<void> _recordStudyDay(String userId) async {
    final userReference = FirebaseFirestore.instance
        .collection('users')
        .doc(userId);
    final snapshot = await userReference.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastValue = data['lastStudyDate'];
    final lastDate = lastValue is Timestamp ? lastValue.toDate() : null;
    final lastDay = lastDate == null
        ? null
        : DateTime(lastDate.year, lastDate.month, lastDate.day);
    final currentStreak = (data['streakDays'] as num?)?.toInt() ?? 0;

    if (lastDay == today) return;
    final nextStreak = lastDay == today.subtract(const Duration(days: 1))
        ? currentStreak + 1
        : 1;
    await userReference.set({
      'streakDays': nextStreak,
      'lastStudyDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _confirmExit() async {
    if (_isExitDialogOpen || _isSubmitting) return;
    _isExitDialogOpen = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.isPracticeMode ? 'Kết thúc luyện tập?' : 'Thoát phòng thi?',
        ),
        content: Text(
          widget.isPracticeMode ? 'Bạn có thể quay lại luyện tập sau.' : 'Bài làm hiện tại sẽ được lưu và chấm theo những câu bạn đã trả lời. Các câu chưa làm sẽ tính là chưa trả lời và bạn không thể thi lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.isPracticeMode ? 'Kết thúc' : 'Lưu và thoát'),
          ),
        ],
      ),
    );
    _isExitDialogOpen = false;
    if (shouldExit != true || !mounted) return;
    if (widget.isPracticeMode) {
      Navigator.pop(context);
    } else {
      await _saveOfficialSubmission(status: 'abandoned');
    }
  }

  Future<void> _recordPracticeStreak() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) await _recordStudyDay(userId);
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    super.dispose();
  }
}
