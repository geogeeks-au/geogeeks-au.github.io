// # Projects Template
// - Big identfier for project lead + contact details
// - Title, Short Description
// - Project Tasks/Structure Checklist
//   - Hidden longer description/GH issues/more details link
//   - Skills Icons/Tags
//   - People's Photos/Initials
// - Project details - long description
// - Update log
// - GH Repo, et cetera
 
// - Take the 5 best project ideas so far and fill out the project template ourselves to generate projects ideas ppl can take "off the shelf".

// "Choose a task you can do OR Choose a task with a skill you'd like to learn and team up with the person doing it."


// Inspired by...
// http://thevectorlab.net/flatlab/todo_list.html
// http://wrapbootstrap.com/preview/WB0H6TMC9

$(function() {
    var known_tags = [
        "android", "brainstorm", "cplusplus", "csharp", "css", "dotnet", "excel", "gis", "html", "illustrator", "ios", "java", "javascript", "photoshop", "php", "planning", "presentation", "python", "question", "research", "ruby", "swift", "wordpress"
    ];

    var tasklist = $(".project-tasks[data-repo-name]");

    var github_issues_url = "https://api.github.com/repos/geogeeks-au/" + tasklist.data("repo-name") + "/issues";
    $.ajax(github_issues_url)
        .done(function(data, textStatus, jqXHR) {
            var template = $('#project-task-item').html();
            Mustache.parse(template);

            $.each(data, function(index, value) {
                if(value.labels.length > 0) {
                    // Map labels to known tags
                    value.skills = $.grep(value.labels, function(label) {
                        if(label.name.indexOf("skill-") != -1) {
                            label.name = label.name.split("skill-")[1];
                        }
                        return (known_tags.indexOf(label.name) != -1);
                    });

                    tasklist.append(
                        Mustache.render(template, value)
                    );
                }
            })
        });
});