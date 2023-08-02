
const gallery = document.getElementById('commons-gallery');
let pages = null;
let categoryTitle = null;
if (gallery && gallery.dataset.commonsCategory) {
    categoryTitle = 'Category:' + gallery.dataset.commonsCategory;
    jsonpcall({
        action: "query",
        prop: "imageinfo",
        generator: "categorymembers",
        iiprop: "url|metadata",
        iiurlwidth: "500",
        gcmtitle: categoryTitle,
        gcmtype: 'file',
        callback: 'commonsCallback'
    });
}

function jsonpcall(params) {
    params.format = 'json';
    params.formatversion = 2;
    const url = new URL('https://commons.wikimedia.org/w/api.php');
    Object.keys(params).forEach(function(key){
        url.searchParams.append(key, params[key]);
    });
    var scriptTag = document.createElement('script');
    scriptTag.src = url;
    document.body.appendChild(scriptTag);
}

function commonsCallback(response) {
    if (response.query === undefined) {
        return;
    }
    pages = response.query.pages;
    const pageIds = [];
    Object.keys(pages).forEach((key) => {
        pageIds.push(pages[key].pageid);
    });
    const mediaIds = pageIds.map(i => 'M' + i).join('|');
    jsonpcall({
        action: 'wbgetentities',
        ids: mediaIds,
        callback: 'commonsEntitiesCallback',
    });
};

function commonsEntitiesCallback(response) {
    const photos = [];
    Object.keys(pages).forEach((key) => {
        const page = pages[key];
        if (page.imageinfo == undefined) {
            return;
        }
        let time = '';
        for (let i in page.imageinfo[0].metadata) {
            if (page.imageinfo[0].metadata[i].name === 'DateTimeOriginal') {
                time = page.imageinfo[0].metadata[i].value.slice(11,16);
            }
        }
        let caption = null;
        try {
            caption = response.entities['M' + page.pageid].labels.en.value;
        } catch (e) {
            caption = '[No caption; please add one!]';
        }

        photos.push({
            url: page.imageinfo[0].descriptionurl,
            thumburl: page.imageinfo[0].thumburl,
            time: time,
            caption: caption,
            landscape: page.imageinfo[0].thumbheight > page.imageinfo[0].thumbwidth,
        });
    });

    photos.sort((a, b) => b.time.localeCompare(a.time));

    photos.forEach(photo => {
        const link = document.createElement('a');
        const colspan = photo.landscape ? 2 : 3;
        link.classList.add(...['figure', 'col-md-' + colspan, 'gallery-item']);
        link.href = photo.url;

        const figure = document.createElement('figure');

        const time = document.createElement('strong');
        time.textContent = photo.time + ': ';
        const figcaption = document.createElement('figcaption');
        figcaption.append(time, photo.caption);

        const image = document.createElement('img');
        image.src = photo.thumburl;
        image.classList.add(...['figure-img', 'img-fluid', 'rounded']);

        figure.append(image, figcaption);
        link.append(figure);
        gallery.prepend(link);
    });

}
