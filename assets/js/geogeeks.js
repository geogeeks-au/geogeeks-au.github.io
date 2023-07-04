
const gallery = document.getElementById('commons-gallery');
let pages = null;
let categoryTitle = null;
if (gallery) {
    categoryTitle = 'Category:' + gallery.dataset.commonsCategory;
    jsonpcall({
        action: "query",
        prop: "imageinfo",
        generator: "categorymembers",
        iiprop: "url",
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
    Object.keys(pages).forEach((key) => {
        const page = pages[key];
        if (page.imageinfo == undefined) {
            return;
        }

        const link = document.createElement('a');
        const colspan = page.imageinfo[0].thumbheight > page.imageinfo[0].thumbwidth ? 2 : 3;
        link.classList.add(...['figure', 'col-md-' + colspan, 'gallery-item']);
        link.href = page.imageinfo[0].descriptionurl;

        const figure = document.createElement('figure');

        const figcaption = document.createElement('figcaption');
        const imageMeta = response.entities['M' + page.pageid] ?? null;
        if (imageMeta && imageMeta.labels.en.value !== undefined) {
            figcaption.textContent = response.entities['M' + page.pageid].labels.en.value;
        }

        const image = document.createElement('img');
        image.src = page.imageinfo[0].thumburl;
        image.classList.add(...['figure-img', 'img-fluid', 'rounded']);

        figure.append(image, figcaption);
        link.append(figure);
        gallery.prepend(link);
    });

}
