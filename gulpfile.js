var gulp = require('gulp');
var gulpUtil = require('gulp-util');
var coffee = require('gulp-coffee');

gulp.task('coffee', function() {
  gulp.src('./src/**/*.coffee')
    .pipe(coffee({bare: false}).on('error', gulpUtil.log))
    .pipe(gulp.dest('./lib/'))
});

gulp.task('default', ['coffee']);
