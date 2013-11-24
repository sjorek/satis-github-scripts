satis-github-scripts
====================

Shell script helper, useful to publish satis-repositories to github-pages.

To publish satis-repositories automatically to github's pages add the following
code-snippet to your *composer.json*:

    {
        …
        "require-dev": {
            "sj/satis-github-scripts": "dev-master",
        },
        "repositories": [
            {
                "type": "composer",
                "url": "http://sjorek.github.io/satis-github-scripts"
            }
        ],
        "scripts" : {
            "post-install-cmd" : [
                "[-x vendor/bin/satis-github-publisher.sh ] && vendor/bin/satis-github-publisher.sh"
            ],
            "post-update-cmd" : [
                "[-x vendor/bin/satis-github-publisher.sh ] && vendor/bin/satis-github-publisher.sh"
            ]
        }
        …
    }
