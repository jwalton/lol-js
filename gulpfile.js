var gulp = require('gulp');
var gulpUtil = require('gulp-util');
var streamline = require('gulp-streamlinejs');
var coffee = require('gulp-coffee');

gulp.task('coffee', function() {
  gulp.src('./src/**/*.coffee')
    .pipe(coffee({bare: false}).on('error', gulpUtil.log))
    .pipe(gulp.dest('./lib/'))
});

gulp.task('streamline', function() {
  gulp.src(['./src/**/*._coffee'])
    .pipe(streamline())
    .pipe(gulp.dest('./lib'));
});

gulp.task('default', ['coffee', 'streamline']);
