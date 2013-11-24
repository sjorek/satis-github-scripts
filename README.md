satis-github-scripts
====================

Shell script helper~~s~~, useful to publish satis-repositories to github-pages.

Adding the repository to *composer.json* and publish automatically:

    {
        …
        "repositories": [
            {
                "type": "composer",
                "url": "http://sjorek.github.io/satis-github-scripts"
            }
        ],
        "scripts" : {
            "post-install-cmd" : [
                "vendor/bin/satis-github-publisher.sh"
            ],
            "post-update-cmd" : [
                "vendor/bin/satis-github-publisher.sh"
            ]
        }
        …
    }
